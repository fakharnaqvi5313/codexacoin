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

## What backs it — deliberately not decided here

How much CAC gets locked as the reserve, and therefore how much `CAC`
asset gets issued on Stellar, is a real financial commitment and is the
project owner's decision, not something to invent. A dedicated CAC-chain
wallet was created to hold whatever reserve amount is decided
(`stellar-reserve` wallet, address `CPC7aKaDBkxFVTBugZGojSm8kwWeQ5qyfS`
on the live mainnet node) — nothing has been sent to it yet.

## What's needed before this can go live

1. **Fund the two Stellar accounts** — a small amount of real XLM sent to
   each public key above (minimum ~1 XLM each just to create the
   accounts; a bit more if you want trustline reserves covered too).
   This is a real transfer of value, so it's the account owner's action
   to take, not something done on your behalf here.
2. **Decide the reserve amount** — how much real CAC to lock in the
   `stellar-reserve` wallet, and therefore how much `CAC` gets issued to
   the distributor to start trading with.
3. **Create the trustline + issue the asset** — once (1) is done, run
   `setup_asset.py` (issuer creates the `CAC` asset, distributor
   establishes a trustline to it, issuer sends the agreed reserve-backed
   amount to the distributor).
4. **Seed liquidity** — create a native AMM pool (e.g. `CAC/XLM` or
   `CAC/USDC`) or place resting DEX orders from the distributor account
   so there's actually something to trade against.
5. **Publish proof-of-reserve** — a public, periodically-updated
   statement showing the `stellar-reserve` CAC balance matches (or
   exceeds) the circulating `CAC` asset supply on Stellar. Without this,
   "backed 1:1" is just a claim, not something anyone can verify — and
   this project's whole ethos so far has been "verifiable, not just
   asserted."
6. **Disclose it** — add a section to the website's Risk Disclosure page
   once this is live, matching how the custodial staking pool is
   disclosed.

Steps 1-2 need the project owner's decision/action. Steps 3-6 can be done
here once those are settled.
