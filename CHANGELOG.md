# Changelog

All notable changes to the CodexaCoin project. Format is loosely
[Keep a Changelog](https://keepachangelog.com/); dates are UTC.

## Phase 1 — Fork, rebrand, and reconfigure the core

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
type, stand up seed infrastructure).

- **Qt GUI wallet built** (2026-07-31, during Phase 2 work): `qt@5` had no
  prebuilt Homebrew bottle on this macOS version and was built from full
  source (~57 minutes). `CodexaCoin-Qt.app` assembled via the project's own
  `make` bundle target and verified to launch and initialize correctly
  (wallet creation, staking thread startup — confirmed via its own
  debug.log, same as the daemon). Dynamically linked against the
  Homebrew-installed Qt/libevent, so it runs on this machine but isn't yet
  a portable, ship-to-another-Mac bundle (would need the
  `macdeployqtplus` framework-bundling step).

---

## Phase 2 — Testnet and regtest validation

### 2026-07-31

- **Two real coin-age reward bugs found and fixed**, both caught
  specifically by multi-node functional testing that exercises scenarios
  Phase 1's single-node verification never did (a node staking *received*
  coins, not just self-mined ones; two independently-staking nodes
  reconnecting and needing to agree on each other's blocks):
  - **Wallet overpay bug**: `wallet/staking.cpp` read a wallet
    transaction's `tx->nTime` directly for coin-age. `CTransaction` only
    serializes `nTime` for `nVersion<2`; this codebase's `nVersion=2`
    transactions always deserialize it as `0`. For *received* coins this
    made age ≈ the full Unix timestamp, clamped to the 60-day age cap,
    inflating a single coinstake's reward by **~21,600×**. `ConnectBlock`
    correctly rejected every such block, so nothing bad was ever accepted
    on-chain, but the wallet could never construct a valid coinstake from
    received funds at all.
  - **Cross-node disagreement bug**: the first fix's fallback (mirroring
    the kernel-hash code's `Coin.nTime`-if-set pattern) used a value
    that isn't canonical across nodes — nonzero only if *that node*
    happened to mine the input's block itself. Two nodes could compute
    two different maximum-allowed rewards for the identical coinstake
    depending purely on which one mined the spent input, and a receiving
    node could reject the originating node's own honestly-built block.
    Reproduced live: a real `coinstake pays too much` rejection
    immediately after two independently-staking nodes reconnected.
  - **Fix**: both the consensus check (`pos.cpp::GetCoinstakeMaxReward`)
    and the wallet (`wallet/staking.cpp::GetWalletTxOriginTime`) now
    resolve coin-age origin time via *only* the origin/confirming block's
    own canonical header time — identical on every node regardless of
    mining-vs-syncing history. Re-verified exact-to-the-satoshi after the
    fix (previously tolerance-bounded to absorb the bug's own timing
    slop). Full writeup: `PARAMETERS.md` §6.3.
- **Functional test suite added**: `feature_premine.py` (exact supply,
  PoW-rejection-past-window), `feature_coinage_reward.py` (formula
  verification against a live staked block), `feature_pos_reorg.py`
  (two nodes independently stake, reconnect, must converge to a single
  consistent chain and supply — the test that caught both bugs above).
  Also fixed a pre-existing, unrelated bug in the inherited test
  framework itself (`test_node.py`'s `v2transport` parameter was
  referenced but never declared, breaking *every* functional test's node
  startup) and documented a real but harmless timing behavior:
  rapidly bulk-mining the premine window leaves the chain's
  median-time-past minutes ahead of real wall-clock time, so staking
  correctly pauses until real time catches up (`PARAMETERS.md` §6.2) —
  not a hang, but worth knowing before assuming something's broken.
- **Docker Compose 3-node regtest environment** added (`docker/`):
  three `codexacoind` nodes on a private network plus a one-shot `init`
  service that mines the premine, verifies it via the (unmodified)
  `audit_premine_supply.py`, confirms PoW rejection past the window, and
  confirms PoS propagation across all three nodes. **Not independently
  executed** — no Docker runtime is installed in this environment: this
  is reviewed-consistent-with-the-real-build config, not a verified test
  run. The same behavior *is* independently verified without Docker via
  the new functional tests.
- **Testnet seed node provisioning scripts** added (`provisioning/`):
  idempotent shell script for a pure P2P relay/validating node — no
  wallet (`--disable-wallet`), no premine, no keys, systemd service,
  firewalled to the P2P port only.
- **Testnet faucet** added (`faucet/`): minimal Flask app, per-IP and
  per-address rate limiting, honeypot instead of external CAPTCHA. Found
  and fixed two bugs while smoke-testing: Flask-Limiter's rate-string
  parser silently no-ops on a fractional hour count (fixed by expressing
  the limit in whole minutes), and a port-5000 conflict (a stale process
  plus macOS's own AirPlay Receiver default) that made a "restart" look
  like it hadn't fixed anything when the old process was still serving
  requests.

See `PARAMETERS.md` §9 for what's still open before any public launch.

---

## Phase 3 — Desktop wallet builds (Windows, Linux, macOS)

### 2026-07-31

- **macOS `.dmg` built and verified end-to-end.** `macdeployqt` bundles the
  Qt frameworks into `CodexaCoin-Qt.app` (confirmed via `otool -L`: no more
  external Homebrew/Qt paths, only standard macOS system libraries), then
  `hdiutil` packages it with an `Applications` symlink into
  `CodexaCoin-Core-macOS.dmg` (~31MB, checksum-verified). Relaunched the
  bundled app directly to confirm it still initializes correctly after
  bundling. Scripted as `contrib/macdeploy/build_dmg.sh` (reusable, not a
  one-off manual sequence) — also prints the exact `codesign`/
  `notarytool`/`stapler` commands needed before public distribution
  (`PARAMETERS.md` §10; no Apple Developer ID certificate exists in this
  environment).
- **GitHub Actions release workflow added**
  (`.github/workflows/release.yml`): builds Linux (tarball + `.deb` via
  `fpm`), Windows (NSIS installer), and macOS (`.dmg`, native runner) on
  tag push, publishing a draft GitHub Release with all artifacts attached.
  Reuses the already-proven Ubuntu-runner + `depends/` cross-compilation
  matrix from the existing `build.yml` CI workflow rather than re-deriving
  build configuration. **Not run end-to-end** — needs an actual tag push
  to fully verify; the macOS leg is the only one independently verified
  locally this session.
- **Windows and Linux builds not produced locally** — genuine environment
  constraints, not toolchain problems, both documented in detail in
  `PARAMETERS.md` §9 item 9: Windows' mingw-w64 cross-compiler works fine
  (Boost/libevent built successfully via `depends/`) but the Qt 5.15.10
  source download reset mid-transfer from `download.qt.io` on two separate
  attempts, and the depends system's fallback mirror 404s for this exact
  file; Linux cross-compilation from a bare macOS host isn't supported by
  the depends system at all (it expects a pre-installed cross-compiler,
  matching Ubuntu's `apt-get` pattern — it doesn't build one from scratch,
  and none is available via Homebrew in a supported form). Both are
  expected to work fine on GitHub Actions' Ubuntu runners, which is what
  the release workflow actually relies on.
- **Qt UI staking controls added**, extending Blackcoin More's existing
  (and already fairly complete) staking UI rather than building from
  scratch — it already had a live status-bar icon
  (`updateStakingIcon()`, updated every second) and an
  encrypted-wallet-specific "unlock for staking" flow, but no general
  on/off control and no reward-amount estimate:
  - **"Enable Staking" toggle** (`bitcoingui.h`/`.cpp`): a checkable
    Settings-menu action. Checking it on an encrypted, locked wallet
    reuses the existing `AskPassphraseDialog::UnlockStaking` flow
    (reverting the checkbox if the user cancels); otherwise it calls
    `setEnabledStaking()` directly — including for turning staking *off*,
    which never needs to re-lock the wallet for spending. The checkbox
    stays in sync with actual state (e.g. if staking was toggled via the
    passphrase-dialog path instead) via `updateStakingIcon()`'s existing
    1-second timer, signal-blocked to avoid feedback loops.
  - **Expected monthly reward estimate** (`overviewpage.ui`/`.cpp`): a new
    "Est. monthly reward" row on the Overview page, computed from the
    current spendable balance and the `nStakeRewardAnnualBP` consensus
    parameter (simple, non-compounded — matches the "~1.14%/month" figure
    quoted elsewhere, the number users actually watch accrue, rather than
    the compounded annual figure). This is a UI-only estimate: it uses
    double-precision arithmetic (deliberately, not the 128-bit path
    `pos.cpp`'s actual reward formula uses — naive `int64` multiplication
    here would overflow for any realistically large balance) and doesn't
    account for per-UTXO maturity timing or the 60-day age cap, so it's
    documented as an estimate, never a guarantee, in its own tooltip.

See `PARAMETERS.md` §9/§10 for what's still open before any public launch.

---

## Phase 4 — Light-wallet backend (required for mobile)

### 2026-07-31

- **`electrumx-cac` added**, adapting
  [CoinBlack/electrumx-blk](https://github.com/CoinBlack/electrumx-blk)
  (Blackcoin's own ElectrumX fork) rather than Fulcrum — researched both
  first; Fulcrum has no generic altcoin/PoS transaction support at all
  (BTC/BCH/LTC-specific only), while electrumx-blk already ships a
  Blackcoin-specific transaction deserializer that correctly handles the
  PoS coinstake `nTime` field CAC inherits unchanged, and a
  version-conditional header-hash mixin that already matches this fork's
  real block-version behavior (every CAC block is `nVersion=7`). Added
  `CodexaCoin`/`CodexaCoinTestnet`/`CodexaCoinRegtest` coin-definition
  classes (genesis hash, RPC port, address prefixes from PARAMETERS.md);
  reused the existing Blackcoin transaction deserializer and daemon RPC
  wrapper unmodified since none of that logic needed to change.
- **Verified against a real node**: ran electrumx-cac against a local
  regtest `codexacoind` and confirmed it connects and correctly identifies
  the daemon via the new coin definition. Full end-to-end block indexing
  was not verified locally — both of electrumx's storage backends
  (leveldb/plyvel, rocksdb) failed to build/run on this specific
  development machine's macOS version (12.7.6, below Homebrew's supported
  tier for the rocksdb formula; plyvel hit a runtime ABI/symbol-visibility
  mismatch against Homebrew's leveldb) — an environment packaging issue,
  not a CAC-adaptation problem. The provided Docker image sidesteps it
  entirely via Debian's packaged leveldb.
- **Deployment scripts added** (`provisioning/electrumx/`): idempotent
  shell provisioning script (systemd service, Let's Encrypt via certbot
  standalone — electrumx has native TLS support, no reverse-proxy needed)
  and a Dockerfile (the recommended path given the local packaging issue
  above). Network-aware port ranges (mainnet/testnet/regtest each get
  distinct ports, not just distinct configs, so a misconfigured wallet
  can't silently connect to the wrong chain on a plausible port).
- **Mobile API gateway specified** (`docs/mobile-api.md`): REST/JSON
  endpoints for balance, UTXOs, history, transaction detail (including
  coin-age reward decoding for coinstake transactions), broadcast, and fee
  estimate, each mapped to the specific underlying Electrum-protocol call
  it wraps. Also specifies the Phase 6 staking-service endpoint shapes
  (custodial 6A: status/deposit/withdraw; cold-staking 6B:
  delegate/revoke) as a stable contract for Phase 5 mobile development,
  even though no staking backend exists yet. This is a specification
  only — the gateway service itself is Phase 5/6 implementation work.

See `PARAMETERS.md` §9/§11 for what's still open before any public launch.

---

## Pre-fork history (inherited from Blackcoin More)

Everything above `## Phase 1` in this file is CodexaCoin's own history. The
inherited Blackcoin More changelog (covering the v26.2.x line this fork was
taken from) is preserved unmodified in `codexacoin-core/CHANGELOG.md`.
