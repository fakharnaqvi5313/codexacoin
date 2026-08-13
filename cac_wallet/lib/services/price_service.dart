/// Best-effort CAC/USD price estimate, mirroring web-wallet/price.js
/// exactly -- no CodexaCoin-operated price feed exists (there isn't one
/// to operate). Tries three independent public sources, in order:
///
///   1. BNB Chain, direct: a raw eth_call to the CAC/USDT PancakeSwap V2
///      pair's own getReserves() via a public BSC RPC endpoint -- the
///      actual on-chain reserve ratio, not a third-party indexer's
///      derived number.
///   2. BNB Chain, indirect: the same pool's price via GeckoTerminal's
///      public API (PARAMETERS.md §27.2), used only if the direct RPC
///      call fails (endpoint down, etc).
///   3. Stellar: the last real trade on Stellar's DEX (Horizon) times
///      XLM/USD (CoinGecko's public API), see PARAMETERS.md §18.
///
/// None of these is a reliable market price -- every trade on either
/// pair is a project-seeded one, disclosed in proof-of-reserve.html.
/// Callers must surface that via [CacPrice.source], not present this as
/// a confident number.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

const _cacIssuer = 'GDFWAGH7DX43XFIGRRCJHIQCJTPP3TTZXTXOJMLAAFV6U2AM7W3L2K4Y';
const _bnbPoolAddress = '0x610d052dfafdbd0f8ba6d37ec202e58e4cb7de9a';
const _bscRpcUrl = 'https://bsc-dataseed.binance.org/';
// Pair.getReserves() returns (uint112 reserve0, uint112 reserve1, uint32
// blockTimestampLast). Verified on-chain (not assumed): the pool's
// token0() is USDT, token1() is CAC, both 18 decimals -- see
// PARAMETERS.md §24.5/31.2.
const _getReservesSelector = '0x0902f1ac';

enum CacPriceSource { bnb, stellar }

class CacPrice {
  final double usdPerCac;
  final CacPriceSource source;
  final String? tradeTime;
  const CacPrice({required this.usdPerCac, required this.source, this.tradeTime});
}

/// Returns null if all sources are unreachable or have no data yet --
/// callers should show nothing rather than a stale/fabricated number.
Future<CacPrice?> fetchCacUsdPrice() async {
  return await _fetchPancakeDirectPrice() ?? await _fetchBnbPoolPrice() ?? await _fetchStellarPrice();
}

Future<CacPrice?> _fetchPancakeDirectPrice() async {
  try {
    final resp = await http.post(
      Uri.parse(_bscRpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'eth_call',
        'params': [
          {'to': _bnbPoolAddress, 'data': _getReservesSelector},
          'latest',
        ],
      }),
    );
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = json['result'] as String?;
    if (data == null || data.length < 2 + 64 * 2) return null;
    final hex = data.substring(2);
    final reserveUsdt = BigInt.parse(hex.substring(0, 64), radix: 16);
    final reserveCac = BigInt.parse(hex.substring(64, 128), radix: 16);
    if (reserveCac == BigInt.zero) return null;
    final scaled = (reserveUsdt * BigInt.from(1000000000)) ~/ reserveCac;
    final usdPerCac = scaled.toDouble() / 1000000000;
    if (!usdPerCac.isFinite || usdPerCac == 0) return null;
    return CacPrice(usdPerCac: usdPerCac, source: CacPriceSource.bnb);
  } catch (e) {
    return null;
  }
}

Future<CacPrice?> _fetchBnbPoolPrice() async {
  try {
    final resp = await http.get(
      Uri.parse('https://api.geckoterminal.com/api/v2/networks/bsc/pools/$_bnbPoolAddress'),
    );
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final attrs = json['data']?['attributes'] as Map<String, dynamic>?;
    final usdPerCac = double.tryParse('${attrs?['base_token_price_usd']}');
    if (usdPerCac == null || !usdPerCac.isFinite) return null;
    return CacPrice(usdPerCac: usdPerCac, source: CacPriceSource.bnb);
  } catch (e) {
    return null;
  }
}

Future<CacPrice?> _fetchStellarPrice() async {
  try {
    final tradesResp = await http.get(Uri.parse(
      'https://horizon.stellar.org/trades?base_asset_type=native&counter_asset_type=credit_alphanum4&counter_asset_code=CAC&counter_asset_issuer=$_cacIssuer&order=desc&limit=1',
    ));
    final trades = jsonDecode(tradesResp.body) as Map<String, dynamic>;
    final records = (trades['_embedded']?['records'] as List?) ?? const [];
    if (records.isEmpty) return null;
    final record = records.first as Map<String, dynamic>;
    final xlmPerCac = double.parse(record['base_amount'] as String) / double.parse(record['counter_amount'] as String);

    final xlmPriceResp = await http.get(
      Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=stellar&vs_currencies=usd'),
    );
    final xlmPriceJson = jsonDecode(xlmPriceResp.body) as Map<String, dynamic>;
    final usdPerXlm = (xlmPriceJson['stellar']?['usd'] as num?)?.toDouble();
    if (usdPerXlm == null) return null;

    return CacPrice(
      usdPerCac: xlmPerCac * usdPerXlm,
      source: CacPriceSource.stellar,
      tradeTime: record['ledger_close_time'] as String,
    );
  } catch (e) {
    return null;
  }
}
