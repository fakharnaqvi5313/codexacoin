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

## Phase 5 — Mobile wallet (Android + iOS)

### 2026-07-31

- **Flutter light wallet built** (`cac_wallet/`): BIP39 mnemonic
  create/restore, BIP32 HD derivation (`m/44'/<coin_type>'/0'/0/0`), hand-
  implemented Base58Check/bech32 address encoding checked against the real
  ground-truth addresses from `PARAMETERS.md` §3.1, and a from-scratch
  legacy P2PKH transaction signer (SIGHASH_ALL, low-S DER encoding) —
  built by hand rather than via a generic Bitcoin-family package because
  CAC's ordinary (non-coinstake) transactions use `nVersion=2`, which is
  wire-compatible with standard legacy Bitcoin serialization, making this
  a checkable, standard target rather than a CAC-specific format.
- **Full screen set implemented**: lock (biometric app-lock via
  `local_auth`, gated on app access not per-transaction signing — a
  documented simplification), onboarding (create/restore), home, receive
  (QR via `qr_flutter`), send (QR scan via `mobile_scanner`, manual entry,
  build-sign-broadcast flow), history, staking (status-display only, no
  on-device computation), and settings (network switch, wipe wallet with
  confirmation). Every network call goes through a single narrow
  `GatewayApi` client matching `docs/mobile-api.md`'s spec exactly; no
  gateway is actually deployed yet (Phase 4 was a specification only), so
  every screen degrades gracefully (not a crash) when a call fails.
- **Zero on-device staking, verified structurally**: no
  `WorkManager`/`BGTaskScheduler` registrations, no background isolates,
  no PoW/PoS logic anywhere in the Dart source — the staking screen is
  read-only display plus remote API calls only. Documented in full,
  including the exact Apple/Google policy this satisfies, in
  `docs/store-compliance.md`.
- **Flutter SDK version turned out to be a real macOS 12 compatibility
  wall** (current stable's Dart VM refuses to start on this OS) — worked
  around with an older stable release (3.19.6) rather than fighting the
  host OS. See `PARAMETERS.md` §12.1 for the full finding.
- **22/22 unit tests passing** (6 integration tests correctly skipped, no
  live gateway to test against), including a real ECDSA signature
  verification test proving the hand-rolled signer produces
  independently-verifiable, standard-format signatures, and address
  round-trip tests against Phase 1's real ground-truth addresses. `flutter
  analyze`: 0 issues.
- **Android verified for real, on-device**: built, installed, and
  launched on an emulator, confirmed via `logcat` (no crashes) and an
  on-device screenshot (`adb screencap`) showing the actual onboarding UI
  rendering correctly. Two environment issues found and fixed along the
  way (Gradle/Java 22 incompatibility; `mobile_scanner`'s minSdkVersion
  requirement) — see `PARAMETERS.md` §12.3.
- **iOS not verified this phase.** Xcode and the Simulator runtime work
  fine, but CocoaPods isn't installed and installing it on this machine
  triggers building LLVM from source — a multi-hour compile with no
  precompiled bottle available here, a disproportionate cost given
  Android already gives real, on-device confirmation of the entire shared
  Dart codebase. Documented, not silently skipped — see `PARAMETERS.md`
  §12.4.
- **Mainnet founder premine window (`PARAMETERS.md` §5) begun for real**,
  alongside this phase's mobile work: the actual mainnet genesis was
  mined in an earlier phase but block 1 onward had never been produced.
  Mining block 1 via the wallet's own `generatetoaddress` worked
  immediately. Mining further blocks with a proper multi-threaded miner
  (`cpuminer-opt`, built locally, `--algo=scrypt`) surfaced three real
  bugs in that generic mining tool's coinbase construction — none of them
  CAC consensus-code issues, all in the tool's assumptions about a
  "standard" Bitcoin-family chain that this fork's PoS-derived
  serialization doesn't quite match:
  1. **Coinbase `nVersion`**: the tool hardcodes `nVersion=1`, but CAC's
     `CTransaction` deserializer expects a legacy 4-byte `nTime` field for
     any `nVersion<2` (`transaction.h`) that the tool never emits,
     corrupting parsing. Fixed by patching the tool to emit `nVersion=2`
     (matching what CAC's own internal miner already produces).
  2. **Missing `vchBlockSig`**: `CBlock` serializes as `header + vtx +
     vchBlockSig` (`block.h`) — a PoS-chain field, empty for PoW blocks,
     but the empty-length byte still has to be present. The tool, having
     no concept of this field, never appended it, so the node's
     deserializer hit end-of-stream. Fixed by appending the one required
     byte.
  3. **BIP34 height encoding for heights 1–16**: CAC's `bad-cb-height`
     check compares against `CScript() << nHeight`, and Bitcoin Core's own
     `operator<<(int64_t)` special-cases heights 0 and 1–16 as a single
     `OP_N` opcode byte, not a length-prefixed push — which only matters
     for a brand-new chain's very first ~16 blocks. Bitcoin Core's own
     coinbase-building code (`node/miner.cpp`) also unconditionally
     appends a trailing `OP_0` after the height, satisfying the
     consensus-enforced ≥2-byte minimum coinbase scriptSig length even in
     the 1-byte-`OP_N` case; replicated the same convention in the
     patched miner. Found via a debug-only improvement to `submitblock`'s
     error message (`rpc/mining.cpp`) to include the actual
     `BlockValidationState::ToString()` reason instead of a generic
     string — a real diagnostic gap in code from an earlier phase, fixed
     as part of tracking this down.
  As of this writing mining is ongoing in the background toward block
  500; see `PARAMETERS.md` §5 for the design this is executing and §9 for
  its status as an open pre-launch TODO.

See `PARAMETERS.md` §12 for full details on what was and wasn't verified
this phase, and its open TODOs.

---

## Phase 6 — VPS staking service and web wallet

### 2026-08-01

- **`docs/mobile-api.md` implemented for real** (`vps-gateway/`) — Phase 4
  left it as a specification only; this phase built the actual Flask
  service, backed by direct `codexacoind` RPC (a watch-only descriptor
  wallet importing addresses on first use) rather than `electrumx-cac`,
  since Phase 4's Electrum backend remains blocked locally by the same
  macOS storage-packaging issue documented back then. mobile-api.md's
  own design already treats the backend as an internal detail behind the
  gateway, so this is a scoped substitution, not a contract change — see
  `PARAMETERS.md` §13.1 for the full reasoning and its real scaling
  limitation versus a proper indexed backend.
- **6A custodial staking pool implemented**: one dedicated on-chain UTXO
  per deposit (never consolidated), so the chain's own already-verified
  coin-age-proportional reward logic (§6) computes each depositor's
  reward correctly on its own — the pool only watches for a deposit's
  UTXO being staked and credits (reward − 5% pool fee), rather than
  reimplementing reward math itself (see §13.2). JWT-based account
  signup/login for the auth mobile-api.md left as "mechanism TBD".
- **Full lifecycle verified end-to-end against a real node on regtest**
  (chosen for controllable coin maturity): deposit → external funding →
  watcher detects it → node stakes it → watcher detects the resulting
  coinstake and computes the reward, matching the wallet's own reported
  amount exactly → 5% fee deducted exactly → status reflects it
  correctly → withdraw → status correctly zeroes out afterward. General
  wallet endpoints (balance/utxos/history/tx-detail/broadcast/
  fee-estimate) verified the same way, including a real `is_coinstake`/
  reward computation against an actual on-chain coinstake transaction.
- **Web wallet built** (`web-wallet/`): a static, bundler-free browser
  wallet using the `@noble`/`@scure` crypto libraries loaded directly as
  ES modules (chosen specifically because they're dependency-free and
  browser-native, unlike most general Bitcoin JS libraries which assume
  Node's `Buffer` and need a bundler) — `crypto.js` mirrors
  `cac_wallet/lib/crypto/*.dart` exactly (same algorithms, same byte
  layouts), so a recovery phrase restores identically on either wallet.
  Verified in a real browser, not just read for correctness: wallet
  creation produced a real, correctly-prefixed mainnet address; balance
  display, staking signup/login/status, and the deposit flow all worked
  against the live gateway.
- **Two real bugs found and fixed during that browser verification**:
  the gateway had no CORS headers at all, silently blocking every
  cross-origin request a browser-based wallet makes by definition (added
  `flask-cors`); and the staking pool's `ensure_*_wallet_loaded` helpers
  swallowed `loadwallet` failures unconditionally, producing a
  confusing "already exists" error instead of the real problem when a
  wallet was stuck from an earlier interrupted process — fixed to check
  `listwalletdir` and surface the actual failure. See `PARAMETERS.md`
  §13.4 for the full list, including three unrelated bugs found in an
  external mining tool while separately mining the founder premine
  window in parallel this phase (not bugs in this project's own code —
  see below).
- **6B (non-custodial cold-staking) deliberately not implemented.**
  The current codebase has no cold-staking script support at all
  (confirmed by searching the tree before writing anything). Rather than
  silently building a new consensus feature — a new opcode, new script
  validation rules, a real hard/soft-fork-shaped deployment decision —
  this phase specified what it would actually require in
  `PARAMETERS.md` §14, following this project's standing rule against
  inventing consensus changes without asking first, applied here to a
  whole feature rather than a single constant.
- **VPS deployment scripts written** (`provisioning/vps-gateway/`):
  systemd units for the gateway (behind gunicorn, not Flask's dev
  server) and a timer-driven staking-pool watcher pass, a Dockerfile,
  and an example nginx reverse-proxy config — same idempotent
  provisioning-script pattern as `provisioning/electrumx/` and
  `provisioning/seed-node/`.
- **Mainnet founder premine mining continued in parallel** (see Phase
  5's entry for how it started): building and fixing the multi-threaded
  external miner surfaced real bugs in that tool's assumptions about
  this fork's PoS-derived transaction/block format — all three
  documented in Phase 5's entry remain the complete list; no new mining
  bugs were found this phase, just continued background progress toward
  block 500.

See `PARAMETERS.md` §13/§14 for full details on what was and wasn't
verified this phase, its open TODOs, and the 6B cold-staking design
specification.

---

## Phase 7 — Block explorer, documentation, and launch readiness

### 2026-08-01

- **Block explorer built** (`explorer/`): public, read-only, no
  authentication or wallet keys — deliberately a separate service from
  `vps-gateway/`, a different trust boundary. Same direct-RPC backend
  approach as Phase 6 (`txindex=1`, already enabled and synced on this
  node, makes arbitrary block/tx lookup by hash/height/txid work
  natively), plus `scantxoutset` for stateless address balance/UTXO
  lookups that don't require importing every queried address into a
  wallet the way the gateway does. Same honest limitation stated
  up front: current balance/UTXOs only, no historical transaction list
  without a real index.
- **Verified in a real browser against the live mainnet node**: home
  page stats, block detail with prev/next navigation, transaction
  detail, and address search — balance exactly matched
  `utxo_count × 28,000,000 CAC` for the mining reward address. The
  transaction detail page incidentally re-confirmed, on real chain data,
  the BIP34 height-encoding fix made to the external mining tool in
  Phase 6 (visible in block 156's coinbase scriptSig).
- **A same-origin API-base bug caught before it shipped**: while writing
  the production nginx config, the frontend's default API base URL was
  changed from a hardcoded local dev address to a same-origin relative
  path — but the fix as first written double-prefixed every request
  path (`/api/api/stats`). Caught immediately by re-checking the actual
  `fetch()` call sites rather than assuming the change was correct, and
  re-verified in a real browser after fixing it.
- **Deployment scripts written** (`provisioning/explorer/`): systemd
  unit (stateless — no data directory, unlike the gateway's), Dockerfile,
  provisioning script, and nginx reverse-proxy example, same pattern as
  every other service in `provisioning/`.
- **Root-level `README.md` written** — did not exist before this phase.
  Project overview, a directory-by-directory map of every subsystem,
  and the cross-service architecture (which services talk to which,
  and why the explorer/gateway/electrumx split exists).
- **Final launch-readiness review** (`PARAMETERS.md` §15.3): every open
  item from §9 and every phase's own "what wasn't verified" notes,
  synthesized into one place and sorted into what's genuinely done, what
  still needs real work, and what's an external/administrative decision
  rather than a technical blocker. Nothing marked done without having
  actually been checked.
- **Founder premine mining continued in the background throughout this
  phase** (started Phase 5, bugs fixed in Phase 6) — at height 161/500
  as of this writing, including surviving a machine sleep/node-restart
  with no manual intervention needed (the external miner reconnected
  automatically). See `PARAMETERS.md` §15.2.

See `PARAMETERS.md` §15 for the block explorer writeup and the complete
final launch-readiness assessment.

---

## Post-launch-readiness feature additions

### 2026-08-01

Five further features scoped and approved via an open "what else should
we add?" pass with the project owner, none part of the original
7-phase spec:

- **Real dynamic fee estimation** (`vps-gateway/app.py`): replaced a
  hardcoded `FEE_RATE_SAT_VB` constant — empirically found to be 10x
  the node's real `mempoolminfee` floor — with a live heuristic driven
  by `getmempoolinfo()`'s actual `mempoolminfee` and mempool fullness.
  Verified live against the running node.
- **P2SH multisig wallet support** added to both `web-wallet/crypto.js`
  and `cac_wallet` (Dart): N-of-M bare multisig in P2SH, a minimal
  hand-rolled partial-signature-exchange proposal format. Verified via
  a real 2-of-3 create/sign/merge/finalize cycle with independent
  signature cross-checks in both languages; `cac_wallet`'s test suite
  grew from 22 to 24 passing tests.
- **Web Push notifications** added to `web-wallet` (new
  `vps-gateway/push.py`, `push_subscriptions` table, two new
  endpoints, `web-wallet/sw.js`), wired into deposit-confirmed and
  reward-credited events in `staking.py`. Browser notification
  permission is hard-denied in this dev environment (a real policy
  constraint); verified instead at the protocol level via a local
  capture server confirming correct VAPID-signed, `aes128gcm`-encrypted
  push requests.
- **Merchant checkout widget** (new `checkout-widget/`): embeddable ES
  module, no new backend endpoint, polls the existing address-balance
  endpoint to detect payment. Verified end-to-end on regtest with a
  real `sendtoaddress` payment correctly detected.
- **Explorer enhancements** (`explorer/app.py`, `explorer/app.js`): new
  `/api/richlist` and `/api/supply-series` endpoints, a hand-rolled
  inline SVG supply chart, a rich-list page, and a 20-second
  auto-refresh timer on the home route. Verified live in-browser: rich
  list balance exactly matched `303 × 28,000,000 CAC`, the chart
  rendered a correct monotonic-ascending line, and an instrumented
  `setInterval`/`clearInterval` check confirmed the refresh timer is
  created and cleared exactly once per navigation, with no leaks.
- **Two ideas deliberately deferred**, following the same precedent as
  Phase 6's 6B cold-staking deferral: on-chain/off-chain **governance**
  and **hardware wallet support**. Both need their own dedicated design
  review before implementation. See `PARAMETERS.md` §17.

See `PARAMETERS.md` §16-17 for the full writeup of all seven items
above.

---

## Founder premine window complete and checkpointed

### 2026-08-01

- **500-block founder premine window finished mining** on mainnet — the
  last remaining "in progress" item from Phase 7 (`PARAMETERS.md` §15.2).
  `audit_premine_supply.py` confirmed the total minted across blocks
  1–500 is exactly `14,000,000,000.00000000 CAC`, constant
  `28,000,000 CAC` per block, zero deviation.
- **Checkpoints frozen**: all 501 block hashes (genesis through block
  500) hardcoded into mainnet's `checkpointData` in `chainparams.cpp`
  (`PARAMETERS.md` §9 item 2, now done — see §5.4). The node was rebuilt
  and restarted with the new checkpoint data and came back up clean at
  the same height, `bestblockhash` matching the newly-hardcoded height-500
  checkpoint exactly.
- **Desktop app rebuilt with the final CAC logo**: `codexacoin-qt`
  recompiled against the regenerated icon set (see the branding update
  above), binary swapped into `CodexaCoin-Qt.app`, Qt framework rpaths
  re-fixed and the bundle re-signed, verified via a clean relaunch.
- **codexacoin.com website built and deployed**: a static pre-launch
  landing site (project overview, real consensus specs pulled directly
  from `PARAMETERS.md`, phase-by-phase roadmap) deployed to a VPS behind
  nginx with a real Let's Encrypt certificate (HTTP→HTTPS redirect,
  apex + `www` both covered). See `provisioning/website/README.md`.

---

## Fixed a chain-halting staking bug found live at height 500

### 2026-08-01

- **A third real staking bug, found the moment the premine window
  finished**: every wallet reported `getstakinginfo` weight `0` and the
  full 14,000,000,000 CAC premine as `"immature"` at height 500 — meaning
  nothing could ever stake, and since PoW is permanently disabled past
  block 500, nothing could ever produce block 501 either. A genuine
  chain-halting deadlock, live on mainnet.
- **Root cause**: `wallet/staking.cpp`'s coin selection for staking
  (`GetStakeWeight`, `AvailableCoinsForStaking`, `CreateCoinStake`) reused
  the wallet's generic "trusted balance" maturity check, which requires
  `nCoinbaseMaturity + 1` confirmations — one more than `pos.cpp`'s actual
  PoS validation rule (`>= nCoinbaseMaturity`), which was specifically
  designed (§5.2) to let the first post-premine block be staked the
  instant PoW ends. The wallet's own implementation was one confirmation
  too conservative and silently reintroduced the exact dead zone the
  design was supposed to prevent.
- **Fix**: added a staking-specific balance helper
  (`GetStakingBalance()`) that agrees with `pos.cpp`'s threshold instead
  of the wallet's generic one; removed the redundant, stricter
  `IsTxImmature()` gate from `AvailableCoinsForStaking`. Ordinary wallet
  balance display and spending are untouched — this only changes which
  coins the local wallet is willing to attempt staking with, not any
  consensus rule, so there's no fork risk.
- **Verified live**: staking weight went from `0` to exactly block 1's
  28,000,000 CAC the moment the fix was deployed; block 501 was produced
  within about a minute, correctly flagged as proof-of-stake, consuming
  block 1's coinbase as its stake input and paying a coin-age-proportional
  reward. See `PARAMETERS.md` §6.4 for the full writeup.

---

## Deployed the block explorer, then root-caused its P2P connectivity

### 2026-08-01

- **Block explorer deployed** to
  [codexacoin.com/blockexplorer](https://codexacoin.com/blockexplorer/),
  backed by its own headless `codexacoind` (no wallet, no keys) built
  from source on the VPS, since no Linux binary existed anywhere in this
  project yet. See `provisioning/explorer/README.md`.
- **A genuine repo gap found and fixed while building it**:
  `src/qt/Makefile`, `src/test/Makefile`, and `src/qt/test/Makefile` had
  never been committed to git since the original Phase 1 fork import —
  plain, hand-written pass-through Makefiles, invisible locally because
  macOS builds never re-run `autoreconf` and just reuse whatever
  `Makefile` is already sitting in the working tree. A clean checkout
  hits it immediately. Fixed by committing the three files.
- **P2P connectivity between the Mac's node and the VPS's node
  investigated and fixed.** Initially looked like a real bug in the
  codebase's connection-management code — every connection attempt
  seemed to vanish with no trace at all. Turned out to be a
  self-inflicted VPS configuration mistake, not a code bug: an arbitrary
  `maxconnections=8` set during initial provisioning caused Bitcoin
  Core's outbound-slot-reservation math to consume all 8 slots for
  outbound alone, leaving zero capacity for inbound connections — every
  inbound attempt was silently dropped as "full," and the actual log
  line explaining why was itself gated behind a debug category that
  wasn't enabled on the VPS side, which is what made it look like a
  silent, unexplained failure at first. Root-caused with `-debug=net`,
  `tcpdump`, and `strace` attached to the live process — the smoking gun
  was `accept() → setsockopt(TCP_NODELAY) → close()` with no `recv`/`read`
  ever called. Fixed by removing the `maxconnections` override (no code
  changes needed); verified immediately after with a full real-P2P sync
  and both nodes showing each other in `getpeerinfo`. See `PARAMETERS.md`
  §9 item 10 for the full diagnostic trail.

---

## All three wallets live: desktop, Android, and web

### 2026-08-01

- **macOS desktop wallet published**: rebuilt `CodexaCoin-Core-macOS.dmg`
  fresh (current binary, final logo/icon) and published it at
  `codexacoin.com/downloads/`. Still unsigned/unnotarized (no Apple
  Developer ID available in this environment, see `PARAMETERS.md` §10) —
  the site says so plainly rather than hiding it.
- **Android APK published**: built a real `--release` APK (not debug),
  fixed the same Gradle/JDK-17 mismatch documented in `PARAMETERS.md`
  §12.3, published at `codexacoin.com/downloads/`. Direct-install only,
  not on the Play Store.
- **Web wallet deployed for real**, with its own backend — this was the
  bigger piece:
  - Rebuilt the VPS's `codexacoind` with wallet support enabled
    (the explorer's build had deliberately used `--disable-wallet`),
    same binary now serving both the explorer and the gateway.
  - Created real `gateway` (watch-only) and `stakingpool` (holds real
    keys) wallets on it, matching the design in `PARAMETERS.md` §13.
  - Deployed `vps-gateway/` as a systemd service
    (`cac-gateway.service` + `cac-gateway-watcher.timer`), with a real,
    freshly-generated `GATEWAY_JWT_SECRET` — not a placeholder.
  - Deployed `web-wallet/`'s static frontend to `codexacoin.com/wallet/`.
    Fixed its `GATEWAY_URLS` default, which had pointed at
    `http://127.0.0.1:8080` (a local-dev-only value) instead of the
    same-origin convention `explorer/app.js` and
    `checkout-widget/checkout.js` already use — nginx proxies `/v1/` to
    the gateway at the site root, same pattern as the explorer's `/api/`.
  - **Verified live, not just "pages load"**: created a real wallet in
    the browser (real BIP39 mnemonic, a real derived address confirmed
    valid via the node's own `validateaddress`), confirmed its balance
    query actually round-tripped through nginx → gateway → node RPC, and
    exercised the staking-pool signup endpoint directly against the
    production JWT secret (then removed the test account from the
    database afterward).
- **Website updated** to match reality: badge changed from "Pre-launch"
  to "Early access," hero copy updated (premine complete, chain is
  staking live), new "Get a wallet" section linking all three, and the
  roadmap now shows the premine-mining and wallet-availability items as
  done.

---

## Website polish, self-attested signup fields, and a deferred referral feature

### 2026-08-01

- **Website visual polish**: hero glow, logo float animation, card/roadmap
  hover states, real button shadows, nav underline animation, and
  focus-visible outlines -- no structural or content changes.
- **Signup collects self-attested KYC fields** (full name, date of birth,
  national ID or passport number) -- explicitly not identity
  verification (no document check, no provider), both the API and the
  UI say so plainly. ID numbers are encrypted at rest via a new
  `GATEWAY_KYC_ENCRYPTION_KEY`; name/DOB stay plaintext. See
  `PARAMETERS.md` section 13.6 for the full reasoning, including why a
  from-scratch "real KYC" wasn't attempted.
- **Referral/airdrop reward requested, not built**: the funding source
  (newly minted supply, taken from the referred deposit, or paid from
  pool fees) was never pinned down, and this project's supply is
  otherwise fixed by design (premine + staking rewards only, no dev
  fund). Building a payout mechanism without deciding that first risked
  either breaking the fixed-supply model or a solvency problem for
  other users' custodial funds. See `PARAMETERS.md` section 13.6.

---

## Referral reward implemented, once the funding source was resolved

### 2026-08-01

- Follows up on the earlier entry deferring this feature. The funding
  question was resolved: 10% of a referred user's first deposit, paid
  from a dedicated `adminwallet` funded manually by the project owner —
  not newly minted CAC, not deducted from the referred user's deposit,
  and not drawn from the pool wallet holding other users' funds.
- `vps-gateway/referral.py`: referral codes generated at signup,
  crediting hooked into the existing deposit-watcher pass (bookkeeping
  ledger entry, not an immediate on-chain send), `/v1/referral/status`
  and `/v1/referral/withdraw` endpoints. Web wallet gained a referral
  code field at signup and a Referrals card showing your code, referred
  count, and a withdraw form.
- Verified the crediting logic and the withdraw endpoint's error path
  live, without moving any real funds (a real transfer is the project
  owner's action, not something to execute while verifying a feature) --
  confirmed exact 10% crediting, no double-credit on a repeat trigger,
  and a clean failure from the still-unfunded admin wallet with the
  credit correctly left available afterward. See `PARAMETERS.md`
  section 13.7 for the full writeup, including the admin wallet's
  receive address.

---

## Appendix A.5 staking-reward unit test suite

### 2026-08-02

- `codexacoin-core/src/test/pos_tests.cpp` (new, registered in
  `Makefile.test.include`): the formal unit test suite for
  `ComputeCoinAgeReward`/`CheckStakeKernelHash` called for by the spec's
  Appendix A.5, which had only ever been exercised via one real end-to-end
  regtest run (`PARAMETERS.md` §6.1) until now. Seven cases: the known
  regtest vector as a regression guard, zero/negative inputs, the age-cap
  plateau, confirmation the 128-bit `arith_uint256` path is actually
  exercised (not dead code) plus a forced-overflow test of the defensive
  int64 clamp, a fast deterministic full-simulated-year calibration (lands
  within 2 satoshis of the nominal annual rate on a 1,000,000 CAC input),
  and a statistical test confirming PoS kernel eligibility stays amount-only
  and uncorrelated with coin-age (3000 trials each at a 1-second vs.
  55-day age, ~50% pass rate either way).
- All seven cases pass under the project's real `make check` invocation.
  Running the full `test_codexacoin` binary unfiltered (not how `make
  check` actually works — each suite gets its own process) surfaces ~34
  unrelated pre-existing failures elsewhere in the suite, traced to a
  hardcoded 2020 mocktime being checked against the real system clock;
  reproduces identically with `pos_tests` excluded, so it predates this
  change and wasn't introduced by it. Left as-is (out of scope for this
  task) but documented in `PARAMETERS.md` §6.1a for whoever picks it up.
- See `PARAMETERS.md` §6, §6.1a, and §9 item 3 for the full writeup.

---

## Dedicated BIP32 extended-key version bytes

### 2026-08-02

- `kernel/chainparams.cpp`: all four networks (mainnet, testnet, signet,
  regtest) previously reused Bitcoin's own `EXT_PUBLIC_KEY`/`EXT_SECRET_KEY`
  version bytes verbatim, so `dumpwallet`/`listdescriptors` output started
  with Bitcoin's literal "xpub"/"xprv" -- indistinguishable at a glance from
  a real Bitcoin extended key. Chose CodexaCoin-specific bytes instead:
  mainnet extended keys now start `Czxx...`, testnet/signet/regtest start
  `DDxx...`. Not consensus-critical (display-only, no validation logic
  touches this), not a breaking change (no UI in this project currently
  serializes an extended key; old backup files stay valid regardless).
- Live-verified against a real, freshly-built `codexacoind`: created a
  descriptor wallet on an isolated mainnet node and confirmed
  `listdescriptors` actually returns the new `Czxx...`-prefixed extended
  pubkey, then repeated on regtest for the `DDxx...` family. See
  `PARAMETERS.md` section 6.4 for the full writeup, including why the
  `EXT_SECRET_KEY`/`dumpwallet` side couldn't be independently re-verified
  live in this build (no BDB/legacy wallet support) despite using the
  identical, already-verified encoding mechanism.
- Closes `PARAMETERS.md` section 9 item 5.

---

## Real Windows and Linux builds, GPG-signed and published

### 2026-08-02

- Asked directly how to handle the request to make downloads warning-free:
  paid code-signing certificates (Windows Authenticode, Apple notarization)
  need real purchases and business/identity verification this project
  can't do unilaterally. Decided: ship real Windows/Linux binaries now with
  GPG signing + SHA256 checksums (free, same scheme Bitcoin Core uses),
  revisit paid certificates later.
- **Windows** (mingw-w64, CLI only): found and fixed two real portability
  bugs that only surfaced on an actual cross-compile attempt -- ~50
  headers missing an explicit `<cstdint>` include (mingw's libstdc++
  doesn't transitively pull it in the way macOS's libc++ does), and a
  `libbitcoinconsensus` shared-library link conflict (fixed via
  `--disable-shared`). Produces real, working `codexacoind.exe`/
  `codexacoin-cli.exe`/etc.
- **Linux** (native Ubuntu 22.04 build inside Docker, full Qt GUI):
  live-verified, not just compiled -- ran the resulting `codexacoind`
  on regtest inside the container and got a real address back from
  `getnewaddress`.
- Generated a real GPG release-signing key, computed `SHA256SUMS` across
  all four release artifacts (macOS, Windows, Linux, Android), signed it,
  and published everything to `codexacoin.com/downloads/` alongside the
  public key. Verified all four checksums against the live server after
  upload. Website gained Windows/Linux wallet cards and a "Verifying a
  download" section explaining plainly that GPG/checksum verification
  proves authenticity but does not suppress OS security warnings -- only
  a paid certificate does that.
- See `PARAMETERS.md` section 10.1 for the full writeup, and section 9
  item 9 (now closed).

---

## Android: real gateway, working staking login/deposit/withdraw, and a launch-blocking crash fix

### 2026-08-03

- The Android app's gateway URL was still a placeholder (`api.codexacoin.
  example`) and its staking screen was fully stubbed despite the gateway
  endpoints existing since Phase 6 -- deposit/withdraw buttons just showed
  a "not live yet" snackbar, and the auth token was silently never sent
  with staking requests. Fixed: mainnet now points at the real
  `codexacoin.com/v1` backend (same one the web wallet uses), added
  login/signup mirroring web-wallet's exact contract (including the
  self-attested KYC fields), and rebuilt the staking screen with a real
  auth form and working deposit/withdraw.
- Found and fixed a real, previously-unknown bug along the way:
  `MainActivity` wasn't a `FragmentActivity`, which the biometric
  app-lock plugin requires -- every fresh install hit
  `no_fragment_activity` and was **permanently stuck on the lock screen**,
  unable to reach any other screen. Not related to this session's other
  changes; just never triggered before because nobody had run the app
  past onboarding with a real emulator/device credential enrolled.
- Verified on a real Android emulator: confirmed the crash is gone,
  created a real wallet through onboarding, and reached the rebuilt
  staking screen. Full deposit/withdraw click-through wasn't finished --
  the emulator became unstable partway through (unrelated to the code
  changes) -- documented honestly rather than claimed as done.
- See `PARAMETERS.md` section 12.6 for the full writeup, closing section
  12.5 item 2.

---

## Android staking verified live end-to-end; stale release APK republished

### 2026-08-03

- Verified the full auth/staking flow added yesterday against the real,
  live gateway (`codexacoin.com/v1`), not just statically: signed up a
  real test account, fetched staking status, requested a deposit address
  (real address returned, no funds moved), and attempted a withdraw
  (clean "exceeds available balance" error -- the safe way to verify that
  path without ever moving real funds). All four matched the exact
  request/response shapes the Dart client now sends. Pivoted to direct
  API testing after the Android emulator became unstable a third time
  across two fresh instances -- confirmed via `aapt2 dump badging` that
  the built APK's own manifest was correct throughout, so this was
  environment tooling instability, not an app defect.
- Cleaned up the test account and its one deposit-address row from the
  production gateway database immediately after verifying.
- Rebuilt and republished the Android release APK at
  `codexacoin.com/downloads/CodexaCoin-android.apk` -- the previous file
  there predated every fix from the day before (real gateway URL,
  working staking, the lock-screen crash fix), so anyone downloading the
  app before this point was getting a build that couldn't reach the
  backend and could get stuck on first launch. Regenerated and re-signed
  `SHA256SUMS`/`SHA256SUMS.asc` to match; verified against the live
  server.
- See `PARAMETERS.md` section 12.7 for the full writeup.

---

## Website content and design overhaul

### 2026-08-03

- Rewrote `website/index.html`/`style.css` for a more professional,
  investor-credible presentation, per explicit request. Every new claim
  ties to something already true and documented elsewhere in this
  project -- no hype copy, no invented statistics.
- New: a hero stats bar pulling real numbers (block height, difficulty)
  live from the explorer's `/api/stats` on page load; a credibility
  strip (audited premine, open source, GPG-signed releases, real
  running network); a "Why Proof-of-Stake" section; an "ecosystem"
  section linking the explorer, gateway, checkout widget, and the newly
  public GitHub repo; an explicit "What we won't tell you" section
  disclosing the project's actual early-stage risks (concentrated
  supply, no exchange listing, unsigned builds, not investment advice);
  and an FAQ.
- Kept the existing dark cyan/blue/gold visual language, added a
  live-updating status badge, icon-led cards, a primary/outline button
  hierarchy, and a dependency-free `<details>`-based FAQ accordion.
- Verified live: fetched stats match the deployed page, no console
  errors, and multi-column layouts confirmed via computed styles at
  both mobile and desktop widths.
- See `PARAMETERS.md` section 16.6 for the full writeup.

---

## First public GitHub repo, first real CI release, v0.1.0 draft published

### 2026-08-03

- Published the project to GitHub for the first time
  (`github.com/fakharnaqvi5313/codexacoin`, public, MIT) -- scanned
  tracked file contents for real secrets first (none found).
- Moved `release.yml` to the actual monorepo root (GitHub Actions never
  discovers workflows nested a directory down) and pushed tag `v0.1.0`.
  `linux-x86_64` and `windows-x86_64` built successfully on GitHub's own
  infrastructure for the first time ever. `macos-x86_64` got stuck queued
  76-90+ minutes on two separate attempts with no error and nothing else
  competing for a runner anywhere in the account -- un-gated
  `publish-release` from needing macOS so future releases aren't held
  hostage by that queue.
- Published a draft GitHub Release for `v0.1.0` with all four platform
  artifacts: the CI-built Linux tarball/`.deb` and Windows installer
  (downloaded directly rather than waiting on a full re-run), plus a
  freshly rebuilt-and-smoke-tested macOS `.dmg`.
- Added the three CI-built artifacts to the website's downloads page too,
  alongside the existing locally-built ones, framed as a second
  independently-built option rather than a replacement. Regenerated and
  re-signed `SHA256SUMS` to cover all seven hosted files.
- See `PARAMETERS.md` section 16.7 for the full writeup.

---

## Legal/policy pages added; Microsoft Store submission blocker found

### 2026-08-03

- Added Privacy Policy, Terms & Conditions (governing law: Pakistan),
  Risk Disclosure, AML/KYC Policy, and Acceptable Use Policy pages under
  `website/legal/`, linked from the site footer and both the web wallet's
  and Android app's signup forms. Every factual claim checked against
  what the code actually does (confirmed no cookies, no third-party
  trackers, before writing those sections that way) rather than using
  generic boilerplate.
- Investigated Microsoft Store submission for a Windows GUI wallet.
  Fetched Microsoft's current Store Policies directly rather than relying
  on memory: policies 10.8.3 and 10.2.6 both require a **Company**
  developer account for any app handling private keys/recovery phrases or
  cryptocurrency wallets -- confirmed with the user that their existing
  account is Individual, which Store policy explicitly disallows for this
  category (a hard certification rejection, not a soft risk). Converting
  requires real business verification with Microsoft that only the
  account owner can do.
- Proceeded with the account-type-independent prep work anyway: building
  an actual Windows GUI wallet via the depends system (the existing
  Windows build is CLI-only), including Qt this time -- the earlier
  attempt had skipped it because the Qt source download kept stalling
  mid-transfer.
- See `PARAMETERS.md` section 16.8 for the full writeup.

---

## First real Windows GUI wallet build

### 2026-08-03

- Achieved a genuine Windows GUI build (`codexacoin-qt.exe` bundled in the
  installer) for the first time, after the local macOS-hosted mingw Qt
  cross-compile hit a real, structural dead end (the host-tool build
  feeds macOS Clang flags to the mingw compiler, which rejects them --
  not fixable, just an unsupported combination).
- Fixed the real bug instead: GitHub Actions' `release.yml` Windows job
  never used `CONFIG_SITE` when calling `configure`, so it never found
  the Qt that `depends` already builds by default -- confirmed by reading
  `depends/config.site.in` directly. That's why the CI-built Windows
  artifact from the last release was CLI-only despite never disabling
  Qt. Fixed, then verified for real: extracted the resulting installer
  with `p7zip` (a `strings` search alone was misleading -- NSIS
  compresses its payload, so it looked empty even when genuinely not) and
  confirmed `codexacoin-qt.exe` (39.3MB) is really in there.
- Replaced the stale CLI-only Windows download on both the GitHub Release
  and the website with this real GUI build, and corrected the homepage
  copy that said Windows was "command-line only for now."
- Still blocked, same as before: real Microsoft Store submission needs
  the account owner to convert to a Company developer account.
- See `PARAMETERS.md` section 16.9 for the full writeup.

---

## DEX listing: chose Stellar, set up (unfunded) issuer infrastructure

### 2026-08-03

- Researched all three requested options (THORChain, Osmosis, Stellar
  DEX) plus XRPL as a close alternative before choosing. THORChain and
  Osmosis are both structurally blocked for a chain like CAC (no smart
  contracts, no IBC) regardless of budget -- THORChain requires its own
  node operators to adopt a new chain-client integration; Osmosis
  requires a purpose-built bridge, the kind of "another blockchain"
  representation explicitly asked to avoid if possible. Stellar's native
  DEX is genuinely near-zero-cost and permissionless, and has meaningfully
  more liquidity than XRPL's equivalent.
- Set up `stellar-issuer/`: generated the two Stellar keypairs (issuer +
  distributor) needed to issue a `CAC` asset, with secret seeds written
  only to a local gitignored file, never logged or committed; created a
  new, empty CAC-chain wallet (`stellar-reserve`) to eventually hold the
  backing reserve; wrote `setup_asset.py`, ready to run once funded.
- Deliberately did not fund the accounts, decide a reserve amount, or
  issue anything -- those are real financial commitments only the
  project owner should make, same standing rule already applied to the
  referral-pool funding decision.
- See `PARAMETERS.md` section 18 for the full writeup.

---

## DEX listing goes live: reserve funded, CAC issued on Stellar, initial offer placed

### 2026-08-03

- Project owner funded both Stellar accounts (issuer and distributor)
  with real XLM, and locked the reserve by sending 10,000,000 real CAC to
  the `stellar-reserve` wallet on the live mainnet node (confirmed
  on-chain, single UTXO, height 1004).
- Ran `setup_asset.py`: distributor established a trustline to the `CAC`
  asset and the issuer sent it the full 10,000,000 reserve-backed amount
  -- verified live via Horizon.
- Ran `place_sell_offer.py`: placed a resting DEX sell offer of 500,000
  CAC against XLM at the owner-chosen initial rate of 1 XLM = 14 CAC
  (price 1/14) -- verified live on Stellar's DEX as offer `1851427700`.
- Published `website/legal/proof-of-reserve.html`: fetches the real
  `stellar-reserve` CAC balance and the issued Stellar `CAC` supply live,
  client-side, from the CAC explorer API and Horizon respectively, and
  compares them -- so "backed 1:1" is independently checkable rather than
  a bare claim. Linked from the site footer and every legal page's nav.
- Added section 10 to `risk-disclosure.html` (`id="stellar-iou"`)
  disclosing the Stellar `CAC` asset's custodial/IOU nature, matching how
  the VPS gateway's custodial staking pool is disclosed in section 5 of
  the same page.
- As with every step in this sequence, all real transactions (funding,
  the CAC reserve transfer, issuing the asset, placing the DEX offer)
  were executed by the project owner directly, never by the assistant --
  each was independently verified afterward via read-only Horizon/CAC
  explorer API calls.
- Still open: locking the issuer account's master key weight to 0 (or
  multisig) to permanently cap further issuance, left for the project
  owner once the reserve amount is treated as final. See `PARAMETERS.md`
  section 18.1 for the full writeup.

---

## Pre-fork history (inherited from Blackcoin More)

Everything above `## Phase 1` in this file is CodexaCoin's own history. The
inherited Blackcoin More changelog (covering the v26.2.x line this fork was
taken from) is preserved unmodified in `codexacoin-core/CHANGELOG.md`.
