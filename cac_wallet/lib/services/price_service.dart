/// Best-effort CAC/USD price estimate, mirroring web-wallet/price.js
/// exactly (same two sources, same reasoning for why this is not a
/// reliable market price): the last real trade on Stellar's DEX
/// (Horizon) times XLM/USD (CoinGecko's public API). No CodexaCoin-
/// operated price feed exists -- there isn't one to operate, see
/// PARAMETERS.md section 18.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

const _cacIssuer = 'GDFWAGH7DX43XFIGRRCJHIQCJTPP3TTZXTXOJMLAAFV6U2AM7W3L2K4Y';

class CacPrice {
  final double usdPerCac;
  final String tradeTime;
  const CacPrice({required this.usdPerCac, required this.tradeTime});
}

/// Returns null if either source is unreachable or has no data yet --
/// callers should show nothing rather than a stale/fabricated number.
Future<CacPrice?> fetchCacUsdPrice() async {
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

    return CacPrice(usdPerCac: xlmPerCac * usdPerXlm, tradeTime: record['ledger_close_time'] as String);
  } catch (e) {
    return null;
  }
}
