// Best-effort CAC/USD price estimate -- no CodexaCoin-operated price feed
// exists (there isn't one to operate). Tries three independent public
// sources, in order:
//
//   1. BNB Chain, direct: a raw eth_call to the CAC/USDT PancakeSwap V2
//      pair's own getReserves() via a public BSC RPC endpoint -- the
//      actual on-chain reserve ratio, not a third-party indexer's
//      derived number.
//   2. BNB Chain, indirect: the same pool's price via GeckoTerminal's
//      public API (PARAMETERS.md section 27.2), used only if the direct
//      RPC call fails (endpoint down, CORS, etc).
//   3. Stellar: CAC/XLM from the last real trade on Stellar's DEX
//      (Horizon's /trades endpoint, not the order book -- a resting offer
//      isn't a price anyone has actually paid), converted to USD via
//      CoinGecko.
//
// None of these are a reliable market price: as of writing, every trade
// that has ever happened on either pair is a project-seeded one,
// disclosed in proof-of-reserve.html. Callers must surface that thinness
// per the returned `source`, not present this as a confident number --
// see how home's balance display labels it.
const CAC_ISSUER = "GDFWAGH7DX43XFIGRRCJHIQCJTPP3TTZXTXOJMLAAFV6U2AM7W3L2K4Y";
const BNB_POOL_ADDRESS = "0x610d052dfafdbd0f8ba6d37ec202e58e4cb7de9a";
const BSC_RPC_URL = "https://bsc-dataseed.binance.org/";
// Pair.getReserves() returns (uint112 reserve0, uint112 reserve1, uint32
// blockTimestampLast). Verified on-chain (not assumed): the pool's
// token0() is USDT, token1() is CAC, both 18 decimals -- see
// PARAMETERS.md section 24.5/31.2.
const GET_RESERVES_SELECTOR = "0x0902f1ac";

async function fetchPancakeDirectPrice() {
  try {
    const resp = await fetch(BSC_RPC_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        id: 1,
        method: "eth_call",
        params: [{ to: BNB_POOL_ADDRESS, data: GET_RESERVES_SELECTOR }, "latest"],
      }),
    });
    const json = await resp.json();
    const data = json?.result;
    if (!data || data.length < 2 + 64 * 2) return null;
    const hex = data.slice(2);
    const reserveUsdt = BigInt("0x" + hex.slice(0, 64));
    const reserveCac = BigInt("0x" + hex.slice(64, 128));
    if (reserveCac === 0n) return null;
    // Both legs are 18 decimals; scale up before dividing to keep precision
    // in a BigInt division, then convert to a float for display.
    const usdPerCac = Number((reserveUsdt * 1_000_000_000n) / reserveCac) / 1_000_000_000;
    if (!usdPerCac || !isFinite(usdPerCac)) return null;
    return { usdPerCac, source: "bnb", tradeTime: null };
  } catch (e) {
    return null;
  }
}

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
  return (
    (await fetchPancakeDirectPrice()) ||
    (await fetchBnbPoolPrice()) ||
    (await fetchStellarPrice())
  );
}
