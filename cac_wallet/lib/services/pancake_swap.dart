/// PancakeSwap V2 Router ABI encoding for the CAC/USDT swap flow on BNB
/// Chain. Pure calldata construction only -- no network calls, no key
/// handling. Signing and broadcasting happen entirely in the externally
/// connected wallet via WalletConnect (see wallet_connect_service.dart).
/// Every address below was verified against BscScan before use, not
/// recalled from memory -- see PARAMETERS.md section 31.
library;

import 'dart:typed_data';

import 'package:web3dart/crypto.dart' show bytesToHex;
import 'package:web3dart/web3dart.dart';

/// "PancakeRouter", BscScan-verified with the "PancakeSwap: Router v2"
/// public name tag, source-code-verified with an exact bytecode match.
final EthereumAddress pancakeRouterAddress =
    EthereumAddress.fromHex('0x10ED43C718714eb63d5aA57B78B54704E256024E');

/// CodexaCoin (CAC) BEP-20, deployed by this project (see bnb-issuer/).
final EthereumAddress cacTokenAddress =
    EthereumAddress.fromHex('0xd9bac2e48E090d42E5E71193D23e8efAAF9a054c');

/// Tether USD (BSC-USD) on BNB Chain -- 18 decimals here, unlike the
/// 6-decimal USDT on Ethereum mainnet (confirmed on BscScan).
final EthereumAddress usdtTokenAddress =
    EthereumAddress.fromHex('0x55d398326f99059fF775485246999027B3197955');

const int cacDecimals = 18;
const int usdtDecimals = 18;

const ContractFunction _erc20ApproveFunction = ContractFunction('approve', [
  FunctionParameter('spender', AddressType()),
  FunctionParameter('amount', UintType()),
]);

const ContractFunction _swapExactTokensForTokensFunction = ContractFunction(
  'swapExactTokensForTokens',
  [
    FunctionParameter('amountIn', UintType()),
    FunctionParameter('amountOutMin', UintType()),
    FunctionParameter('path', DynamicLengthArray(type: AddressType())),
    FunctionParameter('to', AddressType()),
    FunctionParameter('deadline', UintType()),
  ],
);

const ContractFunction getAmountsOutFunction = ContractFunction(
  'getAmountsOut',
  [
    FunctionParameter('amountIn', UintType()),
    FunctionParameter('path', DynamicLengthArray(type: AddressType())),
  ],
  outputs: [FunctionParameter('amounts', DynamicLengthArray(type: UintType()))],
  mutability: StateMutability.view,
);

String _toHexCalldata(Uint8List bytes) => bytesToHex(bytes, include0x: true);

/// ERC-20 `approve(spender, amount)` calldata, as a "0x..." hex string
/// ready to drop into an `eth_sendTransaction` request's `data` field.
String buildApproveCalldata({
  required EthereumAddress spender,
  required BigInt amount,
}) {
  return _toHexCalldata(_erc20ApproveFunction.encodeCall([spender, amount]));
}

/// PancakeSwap Router `swapExactTokensForTokens(...)` calldata.
String buildSwapExactTokensForTokensCalldata({
  required BigInt amountIn,
  required BigInt amountOutMin,
  required List<EthereumAddress> path,
  required EthereumAddress recipient,
  required BigInt deadline,
}) {
  return _toHexCalldata(_swapExactTokensForTokensFunction.encodeCall(
    [amountIn, amountOutMin, path, recipient, deadline],
  ));
}

/// Read-only `getAmountsOut(amountIn, path)` calldata, for use with an
/// `eth_call` (via a public RPC `Web3Client`) to fetch a live quote.
String buildGetAmountsOutCalldata({
  required BigInt amountIn,
  required List<EthereumAddress> path,
}) {
  return _toHexCalldata(getAmountsOutFunction.encodeCall([amountIn, path]));
}

/// Unix seconds `deadline` this many minutes from now, as PancakeSwap's
/// router expects.
BigInt deadlineMinutesFromNow(int minutes) {
  final expiry = DateTime.now().add(Duration(minutes: minutes));
  return BigInt.from(expiry.millisecondsSinceEpoch ~/ 1000);
}

/// Reduces a quoted output amount by [slippageBps] basis points (1/100 of
/// a percent) to get the `amountOutMin` a swap should be willing to accept.
BigInt applySlippage(BigInt quotedAmountOut, {required int slippageBps}) {
  if (slippageBps < 0 || slippageBps > 10000) {
    throw ArgumentError.value(slippageBps, 'slippageBps', 'must be 0-10000');
  }
  return quotedAmountOut * BigInt.from(10000 - slippageBps) ~/ BigInt.from(10000);
}

/// Parses a human-entered decimal amount (e.g. "12.5") into the token's
/// smallest units, without floating-point rounding error. Throws
/// [FormatException] for malformed input or more fractional digits than
/// the token supports.
BigInt parseTokenAmount(String input, int decimals) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Amount is empty');
  }
  if (trimmed.startsWith('-')) {
    throw const FormatException('Amount cannot be negative');
  }
  final parts = trimmed.split('.');
  if (parts.length > 2) {
    throw FormatException('Not a valid decimal amount: $input');
  }
  final whole = parts[0].isEmpty ? '0' : parts[0];
  var frac = parts.length == 2 ? parts[1] : '';
  if (frac.length > decimals) {
    throw FormatException(
      'Too many decimal places for a $decimals-decimal token: $input',
    );
  }
  frac = frac.padRight(decimals, '0');
  return BigInt.parse(whole + frac);
}

/// Formats smallest-unit token amounts back into a human decimal string,
/// trimming trailing zeroes (e.g. 12500000000000000000 @ 18 -> "12.5").
String formatTokenAmount(BigInt amount, int decimals) {
  final digits = amount.toString().padLeft(decimals + 1, '0');
  final whole = digits.substring(0, digits.length - decimals);
  final frac = digits.substring(digits.length - decimals).replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? whole : '$whole.$frac';
}
