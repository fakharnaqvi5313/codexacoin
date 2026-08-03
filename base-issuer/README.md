# CAC on Base — wrapped ERC-20 + Uniswap V2

Makes CAC tradeable on Uniswap by deploying a reserve-backed wrapped ERC-20
on Base (chain id 8453), the same IOU pattern as the Stellar `CAC` asset —
see [stellar-issuer/README.md](../stellar-issuer/README.md) for why no
trustless bridge is possible for an external UTXO chain. This is a
**second, separate custodial liability** from the Stellar one: its own
reserve wallet, its own supply, its own disclosure.

## Why Base over Ethereum mainnet, Arbitrum, or BNB Chain

Decided 2026-08-03 (full reasoning in `PARAMETERS.md` section 19):
mainnet gas is actually cheap again in 2026, but Base's Coinbase-native
on-ramp makes it far easier for a brand-new, zero-audience asset to reach
its first real traders. BNB Chain was ruled out because Uniswap isn't the
dominant venue there (PancakeSwap is) — listing "on Uniswap" specifically
on BSC would be fighting the actual liquidity current.

## Design improvement over the Stellar model

`CodexaCoinBase.sol` mints its entire fixed supply once, in the
constructor, to the deployer. There is no owner, no mint function, no
admin role at all — provably incapable of further issuance from the
moment it's deployed. This is stricter than the Stellar issuer, whose
master key still needs to be manually locked (still open, see
`stellar-issuer/README.md`) to get the same guarantee.

## Status: awaiting funding (2026-08-03)

1. **Reserve wallet created** on the CAC chain:
   `CYKfFa2cfXgKjcLBNPTNFNYBoiNsFfjZV1` (wallet name `base-reserve` on the
   live VPS node). Nothing sent to it yet.
2. **Reserve amount decided**: 2,000,000 CAC — smaller than the Stellar
   reserve (10,000,000), a deliberately conservative size for a second,
   still-unproven venue.
3. **Deployer/distributor wallet generated**:
   `0x744a7f868eBD6Ea933AE49AB8424873CE2894f77`. Pure local key
   generation, no chain interaction, so this step was done directly
   rather than handed to the owner — same as the Stellar keypairs.
4. **Not yet done** (all real value movement — the owner's action, not
   the assistant's, same rule applied throughout this project):
   - Send 2,000,000 CAC to the `base-reserve` address above.
   - Send ETH to the deployer address above: enough to cover gas for two
     transactions plus the 0.05 ETH going into the pool — 0.07 ETH is a
     safe amount.
   - Run `npm run deploy` — deploys `CodexaCoinBase.sol`, minting
     2,000,000 CAC to the deployer.
   - Run `npm run seed-pool` — creates the CAC/WETH Uniswap V2 pool via
     Router02's `addLiquidityETH` (auto-creates the pair if it doesn't
     exist) and seeds it with 0.05 ETH + 7,400 CAC.

## Why 0.05 ETH + 7,400 CAC

Chosen so the Base pool implies roughly the same CAC price as the
existing Stellar peg (1 XLM = 14 CAC), using spot prices from 2026-08-03
(XLM ~$0.175, ETH ~$1,850): 1 CAC ~= $0.0125 => 1 ETH ~= 148,000 CAC. Two
independently-priced venues for the same asset with wildly different
implied valuations would look inconsistent and confusing — there's no
bridge between the two IOUs to arbitrage them into alignment, so keeping
them coherent is a manual, deliberate choice.

## Verified official addresses used (2026-08-03)

Independently confirmed on BaseScan directly, not just Uniswap's docs:
- **Uniswap V2 Router02** (Base): `0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24`
- **Uniswap V2 Factory** (Base): `0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6`
- **WETH** (Base): `0x4200000000000000000000000000000000000006`
- Chain ID `8453`, public RPC `https://mainnet.base.org`

## After it's live

Same obligations as the Stellar side: publish proof-of-reserve (extend
`website/legal/proof-of-reserve.html` with the Base reserve balance vs.
issued Base `CAC` supply), and disclose the custodial nature on
`risk-disclosure.html`.
