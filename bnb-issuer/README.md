# CAC on BNB Smart Chain — wrapped BEP-20 + PancakeSwap V2

Makes CAC tradeable on PancakeSwap by deploying a reserve-backed wrapped
BEP-20 on BNB Smart Chain (chain id 56), the same IOU pattern as the
Stellar `CAC` asset and Base's `CodexaCoinBase` — see
[stellar-issuer/README.md](../stellar-issuer/README.md) for why no
trustless bridge is possible for an external UTXO chain. This is a
**third, separate custodial liability**, distinct from the Stellar and
Base ones: its own reserve wallet, its own supply, its own disclosure.

## Why PancakeSwap on BNB Chain, not Uniswap

Decided when Base was chosen (`PARAMETERS.md` section 19): BNB Chain
was ruled out *for a Uniswap listing* specifically, because PancakeSwap
is the dominant DEX there — listing "on Uniswap" on BSC would be
fighting the actual liquidity current. Listing directly on PancakeSwap
is the natural fit for this chain instead.

## Why the pool is quoted in USDT, not BNB

An AMM pool only holds the *ratio* between its two assets fixed (absent
trades) — it has no concept of USD. Pooling CAC against a volatile
native asset (BNB, or ETH on Base) means CAC's *USD* price
automatically drifts with that asset's own USD price, entirely
unrelated to anything CAC-specific. Quoting against USDT instead (~$1
by Tether's own design) makes the pool's CAC:USDT ratio *be* CAC's USD
price directly — BNB's volatility has no effect on it.

This does **not** make CAC a stablecoin. CAC's USDT price still moves
freely based on actual buying/selling of CAC itself, same as any
token — quoting in USDT only removes *unrelated* volatility bleeding in
from BNB, it doesn't add a redemption mechanism or price defense of any
kind. Worth being explicit about this distinction rather than letting
"priced in USDT" imply more stability than actually exists.

## Design improvement over the Stellar model

Same as `CodexaCoinBase.sol`: `CodexaCoinBnb.sol` mints its entire
fixed supply once, in the constructor, to the deployer. There is no
owner, no mint function, no admin role at all — provably incapable of
further issuance from the moment it's deployed.

## Status: funded, ready to deploy (2026-08-10)

1. **Reserve wallet created and funded** on the CAC chain:
   `CHW6qSWQZnuA1qxsagHkpgX15oBH3LWzxu` (wallet name `bnb-reserve` on
   the live VPS node). Received exactly 2,000,000 CAC, confirmed
   on-chain (txid `abe48d829f090ef19585ae8e91a691f20e4d87a147d38d0f9ba764d873ea189b`,
   block 2701).
2. **Reserve amount decided**: 2,000,000 CAC, matching the Base reserve
   exactly — no reason to size a third venue differently from the
   second.
3. **Deployer/distributor wallet generated and funded**:
   `0x68BCb19e004b5fa6127cb0a1aB28db75f1167F0d`. Pure local key
   generation, no chain interaction, so this step was done directly
   rather than handed to the owner — same as the Stellar/Base
   keypairs. Holds 0.01155907 BNB (gas) and 21.41008673 USDT (pool
   contribution), both confirmed via direct `eth_call`s against BSC's
   public RPC, not just the owner's word.
4. **Not yet done** (all real value movement — the owner's action, not
   the assistant's, same rule applied throughout this project):
   - Run `npm run deploy` — deploys `CodexaCoinBnb.sol`, minting
     2,000,000 CAC to the deployer.
   - Run `npm run seed-pool` — creates the CAC/USDT PancakeSwap V2 pool
     via Router's `addLiquidity` (auto-creates the pair if it doesn't
     exist) and seeds it with 21.41008673 USDT + 1712.8069384 CAC (see
     "Initial liquidity" below).

## Initial liquidity: 21.41008673 USDT + 1712.8069384 CAC

At the shared $0.0125/CAC target price (same peg used for the Base
pool, chosen to keep every venue implying a consistent CAC valuation —
see `PARAMETERS.md` section 19), 21.41008673 USDT of depth needs
1712.8069384 CAC on the other side (the owner's actual USDT
contribution, confirmed on-chain, adjusted down slightly from the
originally discussed 25 USDT). This is a deliberately small first
deposit: since this wallet currently holds the entire circulating CAC
supply that's been made available anywhere, there's no risk of an
uncoordinated market crashing the price by dumping into a thin pool —
liquidity can be added gradually (see "Topping up" below) without that
risk changing.

## Topping up later

The reserve mint (2,000,000 CAC) happens once at deploy and doesn't
need to be repeated. Adding more liquidity later is just another
`addLiquidity` call with larger USDT/CAC amounts, using CAC already
sitting in the deployer wallet from the original mint — no new
contract deployment, no new mint. `create_pool_and_seed.js` can be
re-run with updated `USDT_AMOUNT`/`CAC_AMOUNT` constants when ready (or
ask for a small standalone top-up script instead, if a separate one
becomes more convenient).

## Verified official addresses used

Verified two independent ways before being used in any script: BscScan
contract-page lookup, and a direct `eth_call` to the Router's own
`factory()`/`WETH()` view functions on-chain (this is how the Factory
and WBNB addresses below were actually obtained — not typed in from
memory, which caught a wrong remembered Factory address before it could
end up in a script).

- **PancakeSwap V2 Router**: `0x10ED43C718714eb63d5aA57B78B54704E256024E`
- **PancakeSwap V2 Factory**: `0xcA143ce32fe78f1f7019d7d551a6402fc5350c73`
  (confirmed via the Router's own `factory()` call)
- **WBNB**: `0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c` (confirmed via
  the Router's own `WETH()` call)
- **USDT (Binance-Peg BSC-USD)**: `0x55d398326f99059fF775485246999027B3197955`
  — **18 decimals**, not 6 like Ethereum's USDT; confirmed via a
  `decimals()` call before being used in `create_pool_and_seed.js`.
- Chain ID `56`, public RPC `https://bsc-dataseed.binance.org/`

## After it's live

Same obligations as the Stellar and Base sides: publish proof-of-reserve
(extend `website/legal/proof-of-reserve.html` with the BNB Chain
reserve balance vs. issued BEP-20 `CAC` supply), and disclose the
custodial nature on `risk-disclosure.html`.
