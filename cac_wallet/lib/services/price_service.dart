/// Best-effort CAC/USD price estimate, mirroring web-wallet/price.js
/// exactly -- no CodexaCoin-operated price feed exists (there isn't one
/// to operate). Tries two independent public sources, in order:
///
///   1. BNB Chain: the CAC/USDT PancakeSwap pool's own reserve-ratio
///      price, via GeckoTerminal's public API (PARAMETERS.md §27.2).
///   2. Stellar: the last real trade on Stellar's DEX (Horizon) times
///      XLM/USD (CoinGecko's public API), see PARAMETERS.md §18.
///
/// Neither is a reliable market price -- every trade on either pair is
/// a project-seeded one, disclosed in proof-of-reserve.html. Callers
/// must surface that via [CacPrice.source], not present this as a
/// confident number.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

const _cacIssuer = 'GDFWAGH7DX43XFIGRRCJHIQCJTPP3TTZXTXOJMLAAFV6U2AM7W3L2K4Y';
const _bnbPoolAddress = '0x610d052dfafdbd0f8ba6d37ec202e58e4cb7de9a';

enum CacPriceSource { bnb, stellar }

class CacPrice {
  final double usdPerCac;
  final CacPriceSource source;
  final String? tradeTime;
  const CacPrice({required this.usdPerCac, required this.source, this.tradeTime});
}

/// Returns null if both sources are unreachable or have no data yet --
/// callers should show nothing rather than a stale/fabricated number.
Future<CacPrice?> fetchCacUsdPrice() async {
  return await _fetchBnbPoolPrice() ?? await _fetchStellarPrice();
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
