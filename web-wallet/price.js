// Best-effort CAC/USD price estimate -- no CodexaCoin-operated price feed
// exists (there isn't one to operate). Tries two independent public
// sources, in order:
//
//   1. BNB Chain: the CAC/USDT PancakeSwap pool's own reserve-ratio price,
//      via GeckoTerminal's public API (PARAMETERS.md section 27.2).
//   2. Stellar: CAC/XLM from the last real trade on Stellar's DEX
//      (Horizon's /trades endpoint, not the order book -- a resting offer
//      isn't a price anyone has actually paid), converted to USD via
//      CoinGecko.
//
// Neither is a reliable market price: as of writing, every trade that has
// ever happened on either pair is a project-seeded one, disclosed in
// proof-of-reserve.html. Callers must surface that thinness per the
// returned `source`, not present this as a confident number -- see how
// home's balance display labels it.
const CAC_ISSUER = "GDFWAGH7DX43XFIGRRCJHIQCJTPP3TTZXTXOJMLAAFV6U2AM7W3L2K4Y";
const BNB_POOL_ADDRESS = "0x610d052dfafdbd0f8ba6d37ec202e58e4cb7de9a";

async function fetchBnbPoolPrice() {
  try {
    const resp = await fetch(
      `https://api.geckoterminal.com/api/v2/networks/bsc/pools/${BNB_POOL_ADDRESS}`
    );
    const json = await resp.json();
    const usdPerCac = Number(json?.data?.attributes?.base_token_price_usd);
    if (!usdPerCac || !isFinite(usdPerCac)) return null;
    return { usdPerCac, source: "bnb", tradeTime: null };
  } catch (e) {
    return null;
  }
}

async function fetchStellarPrice() {
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

    return {
      usdPerCac: xlmPerCac * usdPerXlm,
      source: "stellar",
      tradeTime: record.ledger_close_time,
    };
  } catch (e) {
    return null;
  }
}

export async function fetchCacUsdPrice() {
  return (await fetchBnbPoolPrice()) || (await fetchStellarPrice());
}
