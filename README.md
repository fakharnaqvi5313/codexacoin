# CodexaCoin (CAC)

A Proof-of-Stake cryptocurrency forked from
[Blackcoin More](https://github.com/CoinBlack/blackcoin-more), with a
coin-age-proportional staking reward, a 500-block founder premine window,
and a full ecosystem around it: desktop wallet, mobile wallets, a
staking pool service, a web wallet, and a block explorer.

**Start here**: [`PARAMETERS.md`](PARAMETERS.md) is the single source of
truth for every consensus-relevant constant and design decision, with a
running "what was actually verified, and what wasn't" record for every
phase. [`CHANGELOG.md`](CHANGELOG.md) has the full phase-by-phase build
history, including every real bug found and fixed along the way.

## What's in this repository

| Directory | What it is |
|---|---|
| [`codexacoin-core/`](codexacoin-core/) | The forked node (`codexacoind`, `codexacoin-cli`, `CodexaCoin-Qt`) — the actual blockchain software |
| [`cac_wallet/`](cac_wallet/) | Mobile light wallet (Flutter, Android + iOS) |
| [`web-wallet/`](web-wallet/) | Browser-based light wallet (static, no build step) |
| [`vps-gateway/`](vps-gateway/) | REST API backend for the mobile/web wallets, plus the custodial (6A) staking pool |
| [`explorer/`](explorer/) | Public block explorer (backend + static frontend) |
| [`electrumx-cac/`](electrumx-cac/) | Electrum protocol server (forked from `electrumx-blk`) — the originally-designed light-wallet backend; see its README and `PARAMETERS.md` section 11 for its current status |
| [`faucet/`](faucet/) | Testnet faucet app |
| [`docker/`](docker/) | Multi-node regtest environment for local development |
| [`provisioning/`](provisioning/) | systemd/Docker/nginx deployment scripts for every service above that needs a VPS (`seed-node/`, `electrumx/`, `vps-gateway/`, `explorer/`) |
| [`docs/`](docs/) | `mobile-api.md` (the gateway's REST contract) and `store-compliance.md` (App Store / Play Store policy notes for the mobile wallet) |
| [`scripts/`](scripts/) | Standalone utilities (e.g. `audit_premine_supply.py`) |

## How the pieces fit together

```
                     ┌─────────────────┐
                     │  codexacoind     │  the blockchain itself
                     │  (codexacoin-core)│
                     └────────┬─────────┘
                              │ RPC
              ┌───────────────┼───────────────┐
              │               │               │
      ┌───────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐
      │ vps-gateway   │ │  explorer   │ │electrumx-cac│
      │ (wallet API + │ │ (public,    │ │ (indexed,   │
      │ staking pool) │ │ read-only)  │ │ see limits) │
      └───────┬───────┘ └──────┬──────┘ └─────────────┘
              │                │
      ┌───────┴───────┐        │
      │               │        │
┌─────▼─────┐  ┌──────▼─────┐  │
│ cac_wallet │  │ web-wallet │  │ (browsable directly)
│ (mobile)   │  │ (browser)  │  │
└────────────┘  └────────────┘  ┘
```

`cac_wallet` and `web-wallet` share the exact same client-side crypto
logic (BIP39/BIP32 derivation, address encoding, transaction signing) —
implemented twice, once in Dart and once in JavaScript, deliberately
kept byte-for-byte identical, so a recovery phrase created on one
restores identically on the other. See `web-wallet/README.md`'s "Why no
bundler" section for why the JS side doesn't just use a general-purpose
Bitcoin library.

## Design choices worth knowing about before reading further

- **Premine, not inflation**: 14,000,000,000 CAC minted across a
  500-block Proof-of-Work window (`PARAMETERS.md` section 5), mined
  privately before any public launch. This is executing right now on the
  reference node — see `PARAMETERS.md` section 5 and `CHANGELOG.md`'s
  Phase 5/6 entries for the real bugs found in an external mining tool
  along the way (none of them CAC consensus bugs).
- **Staking reward is coin-age-proportional** (`PARAMETERS.md` section
  6), not a fixed per-block subsidy — Peercoin/Blackcoin-style, not
  Bitcoin-style. Two real reward-calculation bugs were found and fixed
  during Phase 2 verification (section 6.3) — worth reading if you're
  extending anything reward-related.
- **No cold-staking (6B) yet.** The custodial pool (`vps-gateway/`, 6A)
  is real and implemented. Non-custodial delegated staking would need a
  brand-new consensus feature (a script opcode, new validation rules,
  a real activation decision) that doesn't exist in this codebase — see
  `PARAMETERS.md` section 14 for what that would actually take, written
  deliberately as a specification rather than being silently implemented.
- **Every service that needs address/transaction lookups faces the same
  tradeoff**: a proper index (`electrumx-cac`) gives full historical
  data but has an unresolved local packaging issue on this particular
  development machine (`PARAMETERS.md` section 11); `vps-gateway` and
  `explorer` both work around it with direct-RPC approaches that are
  real and verified but don't scale the same way. Worth resolving on a
  real target VPS before this goes to real production scale.

## Verification philosophy

Every phase of this project prioritized actually building and running
things over just writing code that looks right — see `PARAMETERS.md`'s
per-phase "what was and wasn't verified" sections and `CHANGELOG.md`'s
entries for the specifics. Where local environment limits blocked full
verification (a macOS-specific packaging issue, missing local
infrastructure, etc.), that's stated plainly rather than glossed over,
with what *was* actually confirmed working stated just as plainly.

## Status

Launch readiness — what's actually done vs. still open before any public
release — is tracked in `PARAMETERS.md` section 9 (updated throughout,
see its own history in `CHANGELOG.md`) and section 15 (the final
Phase 7 launch-readiness review).
