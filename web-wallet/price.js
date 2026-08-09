// Best-effort CAC/USD price estimate, computed from two independent
// public sources -- no CodexaCoin-operated price feed exists (there
// isn't one to operate; see PARAMETERS.md section 18 for why Stellar is
// the only place CAC currently trades at all):
//
//   1. CAC/XLM from the last real trade on Stellar's DEX (Horizon's
//      /trades endpoint) -- not the order book, since a resting offer
//      isn't a price anyone has actually paid.
//   2. XLM/USD from CoinGecko's public API.
//
// This is explicitly NOT a reliable market price: as of writing, the
// only trades that have ever happened on this pair are the two
// project-seeded ones disclosed in proof-of-reserve.html. Callers must
// surface that thinness, not present this as a confident number --
// see how home's balance display labels it.
const CAC_ISSUER = "GDFWAGH7DX43XFIGRRCJHIQCJTPP3TTZXTXOJMLAAFV6U2AM7W3L2K4Y";

export async function fetchCacUsdPrice() {
  try {
    const [tradesResp, xlmPriceResp] = await Promise.all([
      fetch(
        `https://horizon.stellar.org/trades?base_asset_type=native&counter_asset_type=credit_alphanum4&counter_asset_code=CAC&counter_asset_issuer=${CAC_ISSUER}&order=desc&limit=1`
      ),
      fetch("https://api.coingecko.com/api/v3/simple/price?ids=stellar&vs_currencies=usd"),
    ]);
    const trades = await tradesResp.json();
    const record = trades._embedded?.records?.[0];
    if (!record) return null;
    const xlmPerCac = Number(record.base_amount) / Number(record.counter_amount);

    const xlmPriceJson = await xlmPriceResp.json();
    const usdPerXlm = xlmPriceJson?.stellar?.usd;
    if (!usdPerXlm) return null;

    return { usdPerCac: xlmPerCac * usdPerXlm, tradeTime: record.ledger_close_time };
  } catch (e) {
    return null;
  }
}
