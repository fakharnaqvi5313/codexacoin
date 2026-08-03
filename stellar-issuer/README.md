# CAC on Stellar — issuer setup

Makes CAC tradeable on Stellar's built-in, protocol-level DEX (and its
native AMM pools) by issuing a Stellar **credit asset** ("IOU") backed by
real CAC held in reserve. This is infrastructure/setup only — see
[PARAMETERS.md](../PARAMETERS.md) section 18 for the full reasoning
behind choosing Stellar over THORChain/Osmosis/XRPL.

## Why this is an IOU, not "real CAC on Stellar"

CodexaCoin has no native bridge to Stellar (or to anything else). Stellar
has no mechanism to trustlessly mirror an external UTXO chain's native
asset. So this works the same way every non-native asset on Stellar
works: an issuer account creates a custom asset code (`CAC`), and that
asset is only worth anything because the issuer credibly holds real CAC
1:1 in reserve and will redeem it. **This is a custodial liability**,
structurally identical in kind to the VPS gateway's custodial staking
pool (see `PARAMETERS.md` section 13.7) — same honesty obligation
applies: publish what backs it, disclose the risk plainly, don't
overstate what it is.

## Two-account model (standard Stellar practice)

- **Issuer** (`GDFWAGH7DX43XFIGRRCJHIQCJTPP3TTZXTXOJMLAAFV6U2AM7W3L2K4Y`) —
  the account the `CAC` asset code is defined against. Once the initial
  supply is issued to the distributor, this account's signing key should
  be secured as tightly as possible (hardware key / multisig) or its
  master key weight set to 0 (Stellar's standard way to make an issuer
  "cap the supply" — no further issuance possible without additional
  signers) once the reserve amount is finalized. Don't use this account
  for anything else.
- **Distributor** (`GA3VI7RXW347PRMOYIPKGHODVYJAURJCPYJ2MPCM77ZCHST2BBQOHB3W`) —
  holds the actual circulating supply, is the account that creates
  sell/AMM liquidity, and is what most day-to-day operations touch.
  Keeping this separate from the issuer means a compromised distributor
  key can't be used to mint unlimited new supply.

Neither account exists on the Stellar ledger yet — an account only comes
into existence once it receives its first payment (minimum reserve is
currently ~1 XLM per account; see `PARAMETERS.md` §18 for the exact
current numbers this was checked against).

## Status: live (2026-08-03)

All six steps below are complete:

1. **Funded the two Stellar accounts** with real XLM. ✅
2. **Decided the reserve amount**: 10,000,000 CAC, sent to
   `stellar-reserve` (`CPC7aKaDBkxFVTBugZGojSm8kwWeQ5qyfS`) on the real
   CAC chain — confirmed on-chain, single UTXO, height 1004. ✅
3. **Created the trustline + issued the asset**: ran `setup_asset.py`.
   Distributor holds 10,000,000 `CAC`. ✅
4. **Seeded liquidity**: ran `place_sell_offer.py` — resting DEX offer of
   500,000 CAC for XLM at the owner-chosen initial rate (1 XLM = 14 CAC,
   price 1/14). Live on Stellar's DEX as offer `1851427700`. ✅
5. **Published proof-of-reserve**:
   [`/legal/proof-of-reserve.html`](../website/legal/proof-of-reserve.html)
   — fetches the `stellar-reserve` balance and the issued Stellar `CAC`
   supply live from their respective public APIs and compares them, so
   "backed 1:1" is checkable rather than asserted. ✅
6. **Disclosed it**: §10 of
   [`risk-disclosure.html`](../website/legal/risk-disclosure.html)
   (`id="stellar-iou"`), matching how the custodial staking pool is
   disclosed there. ✅

**Still open, deliberately**: the issuer account's master key weight has
not been set to 0 (or moved to multisig) — the standard Stellar way to
permanently cap further issuance. That's a one-way decision, left for the
project owner once 10,000,000 CAC is treated as the final reserve amount
rather than merely the current one.
