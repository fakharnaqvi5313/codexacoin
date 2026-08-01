# vps-gateway

Phase 6 deliverable. Implements `../docs/mobile-api.md` for real — the
mobile app (`../cac_wallet/`) and web wallet (`../web-wallet/`) both talk
to this. Also implements the 6A custodial staking pool (mobile-api.md
section 5's deposit/withdraw/status endpoints).

## Backend choice: direct RPC, not electrumx-cac

`docs/mobile-api.md` was written assuming this gateway sits in front of
`electrumx-cac` (Phase 4). This implementation instead talks directly to
`codexacoind` via RPC, using a dedicated watch-only wallet that imports
any address it's asked about on first use. The REST contract is
identical either way — mobile-api.md's own design treats the backend as
an internal detail. This substitution was made because electrumx-cac's
local verification remained blocked by a macOS-specific storage-backend
packaging issue (see `PARAMETERS.md` section 11) that a real Linux VPS
deployment shouldn't hit, but Phase 6 needed something actually runnable
and verifiable end-to-end during development.

**Known limitation**: unlike electrumx-cac's pre-built global index, this
backend has to `importdescriptors` (with a full rescan) the first time it
sees a new address, which gets slower as the chain grows. Fine for this
project's current chain size and the moderate number of addresses a
staking pool + wallet-backend actually needs to track; **not** a
drop-in replacement for electrumx-cac at real mainnet scale with years
of history. Production deployments serving a large, unpredictable set of
arbitrary addresses should still pursue the Electrum-backed design once
that packaging issue is resolved (trivial on a real Debian/Ubuntu VPS,
which is exactly the target environment `provision.sh` assumes).

## Staking pool design (6A)

Each deposit gets its own dedicated on-chain address/UTXO, funded once
and never consolidated with other users' deposits. This means the
*chain's own* already-verified coin-age-proportional PoS reward logic
(`PARAMETERS.md` section 6) computes each depositor's reward correctly
and independently — the pool never reimplements that math itself, only
detects when a deposit's UTXO gets staked and credits the depositor's
ledger with the reward minus the pool fee. See `staking.py`'s module
docstring for the full reasoning (this deliberately avoids the kind of
reward-calculation bug class documented in `PARAMETERS.md` section 6.3).

Known simplification: `withdraw()` closes out all of a user's active
deposits at once rather than supporting partial withdrawal from a
specific deposit. Fine for this phase's verification scope; a real
production pool would need per-deposit partial-withdrawal accounting.

## Configuration

Environment variables (see `provision.sh` for how these get set in
production):

| Variable | Default | Meaning |
|---|---|---|
| `CAC_RPC_HOST` / `CAC_RPC_PORT` | `127.0.0.1` / `16211` | codexacoind RPC |
| `CAC_RPC_USER` / `CAC_RPC_PASSWORD` | (required) | codexacoind RPC auth |
| `CAC_NETWORK` | `mainnet` | cosmetic only — the RPC connection itself determines the real network |
| `GATEWAY_WATCH_WALLET` | `gateway` | watch-only wallet name for arbitrary-address queries |
| `GATEWAY_POOL_WALLET` | `stakingpool` | real (private-key-holding) wallet for the 6A pool |
| `GATEWAY_JWT_SECRET` | dev-only default | **generate a real one for production** (`openssl rand -hex 32`) |
| `GATEWAY_POOL_FEE_BP` | `500` (5%) | matches `cac_wallet`'s `StakingStatus.notOptedIn` placeholder |
| `GATEWAY_STAKE_REWARD_ANNUAL_BP` | `1368` | must match `consensus.nStakeRewardAnnualBP`, `PARAMETERS.md` section 6 |
| _(none — `/v1/fee-estimate` is computed)_ | — | live `mempoolminfee` floor + a mempool-fullness-based heuristic; no config needed, no `estimatesmartfee`-equivalent RPC exists in this codebase (confirmed empirically) to calibrate against real confirmation-time history instead |
| `GATEWAY_CORS_ORIGINS` | `*` | tighten to the real web wallet's origin in production |
| `GATEWAY_DB_PATH` | `./gateway.db` | SQLite: users, deposits, reward ledger |

## Running locally

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
export CAC_RPC_USER=... CAC_RPC_PASSWORD=... GATEWAY_JWT_SECRET=...
python3 app.py            # dev server, port 8080
python3 watcher.py        # one watcher pass (run periodically -- see gateway-watcher.timer)
```

## Verification (Phase 6)

Full lifecycle verified end-to-end against a real node on regtest
(controllable maturity, so a real coinstake reward could actually be
produced and observed within a test session — mainnet/testnet would
require waiting on real chain time): signup → login (JWT) → get a
deposit address → fund it externally → watcher detects funding →
node stakes it → watcher detects the resulting coinstake, computes the
gross reward (matched the wallet's own reported amount exactly) →
credits net reward after the 5% pool fee (matched exactly) →
`/staking/status` reflects it correctly → withdraw → status correctly
zeroes out afterward. The general wallet endpoints (balance/utxos/
history/tx-detail/broadcast/fee-estimate) were verified the same way,
including a real `is_coinstake`/`reward_satoshis` computation against an
actual coinstake transaction. See `CHANGELOG.md`'s Phase 6 entry and
`PARAMETERS.md` section 13 for the full writeup, including three real
bugs found and fixed in an external mining tool along the way (not bugs
in this gateway or in CAC's consensus code).
