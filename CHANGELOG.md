# Changelog

All notable changes to the CodexaCoin project. Format is loosely
[Keep a Changelog](https://keepachangelog.com/); dates are UTC.

## Phase 1 — Fork, rebrand, and reconfigure the core (in progress)

### 2026-07-31

- **Fork imported.** Cloned `CoinBlack/blackcoin-more` at commit
  `223024fb2fe04be7d3e720dd1660f6e10ab72c88` (`master`/`28.x`, v26.2.x line)
  into `codexacoin-core/`, committed as a pristine baseline before any changes.
- **`PARAMETERS.md` added.** Single source of truth for every
  consensus-relevant constant: magic bytes, ports, address prefixes, bech32
  HRP, BIP44 coin type (placeholder), premine design, staking reward
  formula, and `MAX_MONEY`/`int64` supply-ceiling analysis with 20-year
  projections at 25/50/100% network participation.
- **Full rebrand.** `blackcoin`/`Blackcoin`/`BLACKCOIN`/`BLK` →
  `codexacoin`/`CodexaCoin`/`CODEXACOIN`/`CAC` across source, build scripts,
  Qt resources/forms, man pages, contrib/init service files, and binary
  names (`blackmored` → `codexacoind`, `blackmore-{cli,tx,qt,util,wallet,
  chainstate,node,gui}` → `codexacoin-*`). Generated a placeholder app icon
  and replaced every `bitcoin.{png,ico,icns,xpm}` icon file in place.
  Preserved all original copyright attribution per the MIT license (see
  commit message on the rebrand commit for the details of what had to be
  reverted after an initial overly-broad pass). Fixed
  `MESSAGE_MAGIC` (`util/message.cpp`) from Blackcoin's signing-domain
  string to CodexaCoin's own — this one is functional, not cosmetic.
- **Chain parameters reconfigured** (`kernel/chainparams.cpp`,
  `chainparamsbase.cpp`): new magic bytes, P2P/RPC ports, Base58 address
  prefixes (`C...`/`S...`), bech32 HRP (`cac`/`tcac`/`cacrt`), new genesis
  timestamp phrase, checkpoints reset to genesis-only, `chainTxData` and
  `nMinimumChainWork` zeroed, placeholder `seed*.codexacoin.example` DNS
  seeds (marked TODO), CSV/SegWit active from genesis (fresh chain, no
  legacy activation history to preserve).
- **Premine mechanism.** New `Consensus::Params::nPremineTotal` field;
  `GetProofOfWorkSubsidy()` now mints `nPremineTotal / nLastPOWBlock` per
  block across a fixed `nLastPOWBlock`-block PoW window
  (500 blocks on mainnet — chosen to exactly equal `nCoinbaseMaturity`,
  which closes a chain-halting gap a shorter window would introduce; see
  `PARAMETERS.md` §5.2). Total mints to exactly 14,000,000,000 CAC on
  mainnet/testnet/regtest.
- **Coin-age-proportional staking reward** (spec Appendix A) implemented in
  `pos.cpp` (`ComputeCoinAgeReward`, `GetCoinstakeMaxReward`) using
  128-bit (`arith_uint256`) intermediate arithmetic, and wired into both
  consensus validation (`validation.cpp::ConnectBlock`, replacing the old
  flat `GetProofOfStakeSubsidy()` check with a per-coinstake computed
  maximum) and wallet coinstake construction (`wallet/staking.cpp::
  CreateCoinStake`), so the wallet never builds a block consensus would
  reject. New tunable consensus parameters `nStakeRewardAnnualBP` (default
  1368 = 13.68%/yr ≈ 1.14%/mo) and `nStakeRewardAgeCapSeconds` (60 days).
  **The PoS v3 kernel/stake-eligibility weight
  (`pos.cpp::CheckStakeKernelHash`) was explicitly left untouched** —
  confirmed amount-only, no coin-age term, preserving Blackcoin's existing
  fix against coin-age-hoarding attacks.
- **`MAX_MONEY`**: no code change — already set to the `int64_t` ceiling
  upstream. Documented the real constraint (92,233,720,368 CAC hard ceiling
  from `CAmount` being `int64_t`) and the mitigation (the reward-rate
  parameter is the governance lever) in `PARAMETERS.md` §7.
- **Genesis-mining tool** added: `kernel::FindGenesisBlock()` (exported from
  `kernel/chainparams.cpp`/`.h`) plus a standalone driver,
  `contrib/genesis/generate_genesis.cpp`, that reuses the real
  `CreateGenesisBlock()` rather than reimplementing block/tx serialization.
- **Supply-audit script** added: `scripts/audit_premine_supply.py`, sums
  coinbase outputs for every block in the premine window via RPC and
  asserts the total equals exactly 14,000,000,000 CAC.

- **Genesis blocks mined** for mainnet, testnet, signet, and regtest via
  `generate_genesis`. Found and fixed three real bugs only visible by
  actually running the compiled node (not by code inspection): (1) genesis
  `nVersion` had to be 7, not 1, once the chosen 2026 timestamp landed past
  Blackcoin's inherited protocol-v2 activation time; (2) the genesis
  timestamp phrase had to be short enough for the 100-byte coinbase
  `scriptSig` consensus limit, so the phrase was shortened to a complete,
  unmangled CNBC headline instead of a truncated longer one; (3) PoW
  validation checks `GetPoWHash()` (scrypt), not `GetHash()` — the mining
  tool initially checked the wrong hash and every genesis silently failed.
- **Built successfully**: `codexacoind`, `codexacoin-cli`, `codexacoin-tx`,
  `codexacoin-util`, `codexacoin-wallet` (headless, SQLite wallet, no
  Berkeley DB) on macOS. **Qt GUI wallet not built this phase** — `qt@5` has
  no prebuilt Homebrew bottle on this macOS version and would compile from
  full source (realistically 1-3+ hours); tracked as a Phase 1 follow-up in
  `PARAMETERS.md` §9.
- **End-to-end regtest verification**: ran the real daemon, mined the full
  500-block premine window (confirmed via `scripts/audit_premine_supply.py`:
  exactly 14,000,000,000 CAC, 28,000,000 CAC/block, zero drift), confirmed
  PoW is rejected at block 501 (`reject-pow`), then let the built-in staking
  thread mine PoS blocks. Block 501's coinstake reward
  (6,069,027,198 satoshis) matched the coin-age formula's prediction for
  those exact inputs **to the satoshi**. Chain continued staking normally to
  height 505 before the node was stopped. See `PARAMETERS.md` §6.1 for the
  full numbers.

See `PARAMETERS.md` §9 for the remaining open TODOs before any public
testnet/mainnet launch (mine and checkpoint the *real* mainnet premine
window, write the formal Appendix A.5 test suite, register the BIP44 coin
type, stand up seed infrastructure, build the Qt wallet).

---

## Pre-fork history (inherited from Blackcoin More)

Everything above `## Phase 1` in this file is CodexaCoin's own history. The
inherited Blackcoin More changelog (covering the v26.2.x line this fork was
taken from) is preserved unmodified in `codexacoin-core/CHANGELOG.md`.
