import 'package:flutter_test/flutter_test.dart';

import 'package:cac_wallet/services/pancake_swap.dart';

void main() {
  group('parseTokenAmount / formatTokenAmount', () {
    test('round-trips a plain decimal at 18 decimals', () {
      final units = parseTokenAmount('12.5', 18);
      expect(units, BigInt.parse('12500000000000000000'));
      expect(formatTokenAmount(units, 18), '12.5');
    });

    test('handles a whole number with no decimal point', () {
      expect(parseTokenAmount('7', 18), BigInt.parse('7000000000000000000'));
    });

    test('handles a leading-dot amount like ".5"', () {
      expect(parseTokenAmount('.5', 18), BigInt.parse('500000000000000000'));
    });

    test('formatTokenAmount trims trailing zeroes and an all-zero fraction', () {
      expect(formatTokenAmount(BigInt.parse('3000000000000000000'), 18), '3');
      expect(formatTokenAmount(BigInt.parse('3100000000000000000'), 18), '3.1');
    });

    test('rejects negative amounts', () {
      expect(() => parseTokenAmount('-1', 18), throwsFormatException);
    });

    test('rejects empty input', () {
      expect(() => parseTokenAmount('', 18), throwsFormatException);
      expect(() => parseTokenAmount('   ', 18), throwsFormatException);
    });

    test('rejects more fractional digits than the token supports', () {
      expect(() => parseTokenAmount('1.0000000000000000001', 18), throwsFormatException);
    });

    test('rejects malformed input with multiple decimal points', () {
      expect(() => parseTokenAmount('1.2.3', 18), throwsFormatException);
    });
  });

  group('applySlippage', () {
    test('reduces the quoted amount by the given basis points', () {
      final quoted = BigInt.from(1000);
      expect(applySlippage(quoted, slippageBps: 100), BigInt.from(990)); // 1%
      expect(applySlippage(quoted, slippageBps: 50), BigInt.from(995)); // 0.5%
      expect(applySlippage(quoted, slippageBps: 0), quoted);
      expect(applySlippage(quoted, slippageBps: 10000), BigInt.zero);
    });

    test('rejects out-of-range basis points', () {
      expect(() => applySlippage(BigInt.from(1000), slippageBps: -1), throwsArgumentError);
      expect(() => applySlippage(BigInt.from(1000), slippageBps: 10001), throwsArgumentError);
    });
  });

  group('deadlineMinutesFromNow', () {
    test('returns a unix-seconds timestamp roughly N minutes ahead', () {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final deadline = deadlineMinutesFromNow(20).toInt();
      expect(deadline, greaterThan(nowSeconds + 19 * 60));
      expect(deadline, lessThan(nowSeconds + 21 * 60));
    });
  });

  group('calldata builders', () {
    test('buildApproveCalldata starts with the approve() selector', () {
      final calldata = buildApproveCalldata(
        spender: pancakeRouterAddress,
        amount: BigInt.parse('1000000000000000000'),
      );
      // keccak256("approve(address,uint256)")[0:4] == 0x095ea7b3
      expect(calldata.startsWith('0x095ea7b3'), isTrue);
      // selector (4 bytes) + 2 * 32-byte params = 4 + 64 bytes = 136 hex chars + '0x'
      expect(calldata.length, 2 + 8 + 64 * 2);
    });

    test('buildSwapExactTokensForTokensCalldata starts with the correct selector', () {
      final calldata = buildSwapExactTokensForTokensCalldata(
        amountIn: BigInt.parse('1000000000000000000'),
        amountOutMin: BigInt.zero,
        path: [usdtTokenAddress, cacTokenAddress],
        recipient: usdtTokenAddress,
        deadline: deadlineMinutesFromNow(20),
      );
      // keccak256("swapExactTokensForTokens(uint256,uint256,address[],address,uint256)")[0:4]
      expect(calldata.startsWith('0x38ed1739'), isTrue);
    });

    test('buildGetAmountsOutCalldata starts with the correct selector', () {
      final calldata = buildGetAmountsOutCalldata(
        amountIn: BigInt.parse('1000000000000000000'),
        path: [usdtTokenAddress, cacTokenAddress],
      );
      // keccak256("getAmountsOut(uint256,address[])")[0:4]
      expect(calldata.startsWith('0xd06ca61f'), isTrue);
    });
  });

  group('verified addresses', () {
    test('router, CAC and USDT addresses are well-formed 20-byte addresses', () {
      for (final addr in [pancakeRouterAddress, cacTokenAddress, usdtTokenAddress]) {
        expect(addr.hexNo0x.length, 40);
      }
    });
  });
}
