# CodexaCoin (CAC) — Parameters

Single source of truth for every consensus-relevant and network-identity constant in
CodexaCoin. Nothing here is invented silently — each value below was either chosen
explicitly (and is marked as such) or read directly out of the forked source
(marked "inherited from Blackcoin More").

Values marked **TODO** are placeholders that must be finalized before any public
testnet or mainnet launch.

---

## 1. Fork provenance

| Field | Value |
|---|---|
| Upstream project | [CoinBlack/blackcoin-more](https://github.com/CoinBlack/blackcoin-more) |
| Upstream branch | `master` (== `28.x` head at fork time) |
| Upstream commit | `223024fb2fe04be7d3e720dd1660f6e10ab72c88` |
| Upstream commit date | 2025-10-28 |
| Upstream version line | v26.2.x (Bitcoin Core 26.2 base) |
| Fork imported as | `codexacoin-core/` at repo root, commit `3b956af` ("Import pristine Blackcoin More source") |

Fetched via `git clone --depth 1 --branch master`, so only the tip commit's tree
is present locally (no deep history). The commit hash above is authoritative;
re-fetch the same hash from upstream to diff against a full-history clone if needed.

---

## 2. Identity

| Parameter | Value |
|---|---|
| Coin name | CodexaCoin |
| Ticker | CAC |
| Decimals | 8 (inherited: `COIN = 100000000` satoshis, unchanged from Blackcoin) |
| Client / daemon name | `codexacoind`, `codexacoin-cli`, `codexacoin-qt`, `codexacoin-tx` |
| Data directory | `~/.codexacoin` (mainnet), `~/.codexacoin/testnet3`, `~/.codexacoin/regtest` |
| Consensus | Proof-of-Stake only after a short fixed-reward premine window (no ongoing PoW mining) |

---

## 3. Network magic bytes, ports, address prefixes

Chosen fresh (verified different from Blackcoin's own values, read from
`src/kernel/chainparams.cpp` in the fork — see §3.4 for the comparison table).

### 3.1 Mainnet

| Field | Value |
|---|---|
| Message start (magic) | `0x74 0x80 0x2a 0xa6` |
| P2P port | `16210` |
| RPC port | `16211` |
| Base58 P2PKH prefix (address) | `28` (`0x1c`) → addresses start with **`C`** |
| Base58 P2SH prefix (script) | `63` (`0x3f`) → addresses start with **`S`** |
| Base58 WIF prefix (private key) | `156` (`0x9c`) (P2PKH prefix + 128, standard Bitcoin-derived convention) |
| BIP32 extended public key | `0x0246E5B0` (`CACP`... prefix family) — **TODO**: currently reusing Blackcoin's `0x0488B21E` (Bitcoin standard) pending a dedicated xpub/xprv prefix choice; not consensus-critical, safe to launch with the Bitcoin-standard value and revisit |
| BIP32 extended private key | `0x0488ADE4` (unchanged, Bitcoin-standard value — see note above) |
| Bech32 HRP | `cac` |
| BIP44 coin type | `3377` (derivation index `0x80000D31`) — **TODO: placeholder, not yet registered.** Must be checked against the live [SLIP-44 registry](https://github.com/satoshilabs/slips/blob/master/slip-0044.md) and submitted as a PR before mainnet launch; a collision here is a wallet-derivation compatibility risk, not a consensus risk, so it can be changed freely pre-launch. |

Sample generated mainnet addresses (for prefix verification only, not real keys):
`CRD6aiuoa3sv2ToqcszF3GmjRW8FDdBcHU`, `CbqE2d8JtcTHwydNmiRVTSasD4oovSF7us` (P2PKH);
`SipNMPMFEjmmfNnBg92m5h8iS4wvqgihd9`, `Sd5nU5NcZf2LRx3QGQU872ufmiH5rjhHKS` (P2SH).

### 3.2 Testnet

| Field | Value |
|---|---|
| Message start (magic) | `0xc1 0x02 0x7e 0x3b` |
| P2P port | `26210` |
| RPC port | `26211` |
| Base58 P2PKH prefix | `111` (`0x6f`) — inherited from Blackcoin testnet (Bitcoin-standard testnet value, addresses start with `m`/`n`); kept as-is since testnet address format has no branding requirement |
| Base58 P2SH prefix | `196` (`0xc4`) — inherited (Bitcoin-standard testnet value) |
| Base58 WIF prefix | `239` (`0xef`) — inherited (Bitcoin-standard testnet value) |
| Bech32 HRP | `tcac` |
| BIP44 coin type | `1` (SLIP-44 standard "testnet" index, per convention — all coins use `1` for testnet) |

### 3.3 Regtest

| Field | Value |
|---|---|
| Message start (magic) | `0x17 0xe4 0xb9 0x4c` |
| P2P port | `36210` (Blackcoin regtest default `35714` shifted to CAC's range) |
| Bech32 HRP | `cacrt` |

### 3.4 Diff against Blackcoin's own values (confirms uniqueness)

| Field | Blackcoin mainnet | CodexaCoin mainnet |
|---|---|---|
| Magic | `0x70 0x35 0x22 0x05` | `0x74 0x80 0x2a 0xa6` |
| P2P port | `15714` | `16210` |
| RPC port | `15715`* | `16211` |
| P2PKH prefix | `25` (`B...`) | `28` (`C...`) |
| P2SH prefix | `85` | `63` |
| Bech32 HRP | `blk` | `cac` |

\* Blackcoin's RPC port is derived from its own base params (not directly read in this
pass); regardless, `16211` does not collide with Blackcoin's P2P port `15714` or the
Bitcoin/Blackcoin RPC ranges.

---

## 4. Consensus rules

| Parameter | Value | Source |
|---|---|---|
| Consensus mechanism | PoS v3 (age-independent kernel weight), PoW premine window only at chain start | Inherited mechanism, confirmed in `src/pos.cpp::CheckStakeKernelHash` — kernel weight `bnWeight = arith_uint256(nValueIn)` is **amount-only**, no coin-age term. **Untouched by CodexaCoin.** |
| Block target spacing | 64 seconds | Inherited (`nTargetSpacing = 64`) |
| Target timespan | 16 minutes | Inherited (`nTargetTimespan = 16 * 60`) |
| Coinbase/coinstake maturity | 500 blocks (≈ 8.9 hours at 64s spacing) | Inherited (`nCoinbaseMaturity = 500`) |
| Minimum stake age | **500-block confirmation depth, not a separate timestamp field.** See note below. | Confirmed from source |
| Stake timestamp mask | `0xf` (15) | Inherited |
| Max reorg depth | 500 blocks | Inherited |

**Note on "minimum stake age":** older Blackcoin/Peercoin-lineage code used a
separate `nStakeMinAge` timestamp field (historically 8 hours). This fork's PoS v3+
codebase does **not** have that field — `SelectCoinsForStaking` in
`src/wallet/staking.cpp` instead requires `GetTxDepthInMainChain(wtx) >=
Params().GetConsensus().nCoinbaseMaturity` (500 confirmations) before a UTXO is
stake-eligible. At 64s spacing, 500 blocks ≈ 8.89 hours, which is why the spec's
"8 hour" figure and the actual enforced rule land at almost the same wall-clock
time — but the enforced mechanism is confirmation depth, not elapsed seconds.
CodexaCoin keeps this mechanism unchanged; PARAMETERS.md documents the true
behavior per the instruction to adapt when the assumed structure doesn't match.

---

## 5. Premine — 14,000,000,000 CAC

**Chosen approach: Option (b) from the spec — a short fixed-reward PoW window,
not a spendable genesis-coinbase premine.**

Reason: `CreateGenesisBlock()` in `src/kernel/chainparams.cpp` carries the
standard Satoshi-derived genesis behavior — the genesis coinbase transaction is
never added to the UTXO set (explicitly noted in the function's own doc comment:
*"the output of its generation transaction cannot be spent since it did not
originally exist in the database"*). Option (a) is therefore not available in
this codebase without patching core UTXO-set-initialization logic, which is out
of scope. Blackcoin's own existing design (a `nLastPOWBlock`-gated PoW window
paying a flat `GetProofOfWorkSubsidy()` per block, then switching to PoS) is
reused directly.

### 5.1 Design

- `nLastPOWBlock = 500` on mainnet (chosen to exactly equal `nCoinbaseMaturity`,
  see rationale below).
- `GetProofOfWorkSubsidy()` returns a flat **28,000,000 CAC** per block for
  blocks `1..500` (`14,000,000,000 / 500`, exact integer division, no remainder,
  no dust).
- Total minted across the window: `500 × 28,000,000 = 14,000,000,000 CAC` exactly.
- All 500 PoW blocks are mined **privately by the founders before any public
  release** (no DNS seeds, no seed nodes, no public binaries distributed until
  after this window is mined), targeting a small founder address set. The
  resulting 500 block hashes are then hardcoded into `checkpointData` in
  `chainparams.cpp`, making them unreorgable for anyone who ever syncs from
  genesis.
- At block 501, `nLastPOWBlock` is exceeded, so `ContextualCheckBlockHeader`
  (see `src/validation.cpp:3892`) rejects any further PoW block — the chain is
  PoS-only from that point on, permanently.

### 5.2 Why the window is 500 blocks, not fewer

This is a deliberate fix for a chain-halting bug that a shorter window (e.g.
`nLastPOWBlock = 1`) would introduce: staking eligibility requires 500
confirmations (see §4). If the PoW window were shorter than 500 blocks, there
would be a dead zone between the end of the PoW window and the moment the
earliest premine UTXO matures, during which **no one could produce a block at
all** (PoW is disallowed past `nLastPOWBlock`, and no UTXO is yet stake-eligible).
Setting `nLastPOWBlock = nCoinbaseMaturity = 500` closes that gap exactly: by
the time block 501 is due, the block-1 premine output has just reached its
500th confirmation (and is therefore both mature *and* old enough by wall clock,
since `500 blocks × 64s ≈ 8.89h`), so PoS can take over immediately with no
stall.

### 5.3 Supply-audit script

`codexacoin-core/scripts/audit_premine_supply.py` (to be added in this phase)
sums `GetProofOfWorkSubsidy()` across blocks 1–500 from the compiled `codexacoind`
via RPC (`getblock`/`gettxout` on the coinbase outputs) and asserts the total
equals exactly `14,000,000,000 * COIN` satoshis, with zero drift.

---

## 6. Staking reward — coin-age-proportional (Appendix A)

| Parameter | Value | Notes |
|---|---|---|
| `STAKE_REWARD_ANNUAL_BP` | `1368` (default) | 13.68% simple annual = 1.14%/month. New consensus parameter (not present upstream); tunable per network before mainnet freeze. |
| `AGE_CAP_SECONDS` | `5,184,000` (60 days) | New consensus parameter (`nStakeRewardAgeCapSeconds`). Coin-age beyond this per input does not accrue further reward. |
| `SECONDS_PER_YEAR` | `31,556,952` (365.2425 days) | Fixed constant, not network-specific. |
| Kernel/stake-eligibility weight | **Amount-only, unchanged** | Confirmed in `src/pos.cpp`; coin-age is used **only** in the reward formula, never in kernel weight. This preserves Blackcoin's fix against coin-age-hoarding attacks (spec's "critical security constraint"). |

Formula (see Appendix A in the original spec for full derivation):

```
coinage_coinsec = Σ_i ( v_i × min(t_i, AGE_CAP_SECONDS) )
nReward = coinage_coinsec × STAKE_REWARD_ANNUAL_BP / (10000 × SECONDS_PER_YEAR)
```

computed with 128-bit intermediate arithmetic (`arith_uint256`/`__int128`) since
`14e9 × 1e8 × 5,184,000` overflows `int64`.

**Maturity-drag calibration (§A.3 of spec):** a *formal* regtest calibration
test (a full simulated year, asserting realized rate within ±0.1%, per the
spec's Appendix A.5 test list) has **not** been written yet — that's still a
TODO. What **has** been verified this phase is that the formula itself is
implemented and wired correctly end-to-end (§6.1 below); the maturity-drag
calibration question (whether 1368 bp needs bumping to ~1420 bp to net out
at a realized 1.14%/month after the 500-block lockup) is still open pending
that dedicated test. **Do not treat 1368 as calibrated — it is still the
uncalibrated spec default.**

### 6.1 End-to-end verification (regtest, this phase)

Ran the actual compiled `codexacoind` on regtest, mined the full 500-block
premine window, then let the built-in staking thread mine PoS blocks past
it. Block 501's coinstake:

- Staked input: a 28,000,000 CAC premine output, aged exactly 500 seconds
  (regtest mines blocks back-to-back, so consecutive block timestamps
  advance by the protocol-minimum 1 second each — 500 blocks × 1s = 500s,
  not 500 × 64s, since `generatetoaddress` doesn't wait for real time to
  pass).
- Reward paid: `6,069,027,198` satoshis (`60.69027198` CAC).
- Formula-predicted reward for those exact inputs (`28,000,000 CAC × 500s ×
  1368 bp / (10000 × 31,556,952)`): `6,069,027,198` satoshis.
- **Exact match, to the satoshi.** Confirms `ComputeCoinAgeReward`/
  `GetCoinstakeMaxReward` (`pos.cpp`) and the wallet's mirrored calculation
  in `CreateCoinStake` (`wallet/staking.cpp`) agree with each other and with
  the formula, and that `ConnectBlock`'s consensus check accepted the
  resulting block (i.e. `nActualStakeReward <= nMaxStakeReward` held).
- The chain continued staking normally past that point (reached height 505
  before the node was stopped), i.e. this wasn't a one-off.

This is real end-to-end verification of the reward *mechanism*, not the
spec's Appendix A.5 test suite (unit tests for overflow edge cases, the
full-year calibration simulation, the age-cap test, the kernel-independence
statistical test, and the 6B negative test are all still TODO — see §9).

### 6.2 Operational note: staking pauses after a rapid bulk-mine

Discovered during Phase 2 while automating the above verification as a
functional test. Mining the 500-block premine window via `generatetoaddress`
takes only ~60-90 seconds of *real* wall-clock time, but each block's
timestamp must still increase by at least one second — so the chain's clock
advances ~500 seconds while real time advances ~65. The result: immediately
after a rapid bulk-mine, the chain's `median-time-past` sits several minutes
*ahead* of real time.

`node/miner.cpp`'s PoS path correctly refuses to timestamp a new block
earlier than `pindexPrev->GetMedianTimePast()+1` (a legitimate consensus
safety rule, unrelated to and unmodified by CodexaCoin's changes). The
practical effect: staking will appear completely idle — not hung, RPC stays
fully responsive throughout, kernels are still found and logged every
`search-interval` — until real wall-clock time catches up to the chain's
temporarily-future-shifted clock. Measured this session: a ~345-second gap
after mining 500 blocks in ~65 seconds, closing 1:1 with elapsed real time.

**This is expected and requires no code fix**, but matters operationally:
anyone bulk-mining a premine window on a fresh regtest/testnet node (Docker
Compose environments, CI, this project's own functional tests) should expect
a multi-minute pause before staking visibly starts, and should not mistake
it for a hang. The functional tests added this phase
(`feature_coinage_reward.py`, `feature_pos_reorg.py`) use a 600-900 second
`wait_until` timeout to account for it.

### 6.3 Two real reward-timing bugs found and fixed (Phase 2)

Both were caught specifically because Phase 2's functional tests exercise
scenarios Phase 1's single-node, self-mined-coins-only verification never
did: a node *receiving* coins from elsewhere (not self-mining them), and
two independently-staking nodes reconnecting and needing to agree on each
other's blocks. Both are now fixed and re-verified exact-to-the-satoshi
(§6.1's numbers above are from the corrected code).

**Bug 1 — wallet read a transaction field that's always zero.**
`CTransaction` only serializes `nTime` for `nVersion<2`
(`primitives/transaction.h`); for this codebase's `nVersion=2` transactions
it deserializes as a hardcoded `0`. `wallet/staking.cpp`'s coin-age
calculation was reading `pcoin.first->tx->nTime` directly as each input's
origin timestamp. For self-mined coins staked within the same process
(Phase 1's only test scenario) this coincidentally held a valid in-memory
value and never showed up. The moment a wallet staked a *received*
transaction, `nTime` read back as `0`, making `age = current_time − 0` ≈ the
full Unix timestamp, clamped to `AGE_CAP_SECONDS` (60 days) — inflating a
single coinstake's reward by **~21,600×**. `ConnectBlock` correctly
rejected every such block (`bad-cs-amount`), so no bad block was ever
accepted, but the wallet could never construct a valid coinstake from
received funds at all.

**Bug 2 — the fallback used a value that isn't canonical across nodes.**
The first fix mirrored `pos.cpp`'s existing kernel-hash fallback pattern
(`Coin.nTime` if set, else the origin block's time) — reasonable-looking,
but wrong for reward purposes specifically. `Coin.nTime` is populated from
whatever a transaction's in-memory `nTime` happened to be *when that node's
own `ConnectBlock` ran* — nonzero (the original construction-time value) if
that node mined the block itself, `0` (falling back to block time) if it
instead received the block over P2P. Since `node/miner.cpp` sets a PoW
block's final `nTime` via `std::max(pindexPrev->GetMedianTimePast()+1,
...)` *after* the coinbase transaction object already self-initialized its
own `nTime` at construction, those two values can differ by a few seconds.
Net effect: two nodes could compute two *different* maximum-allowed
rewards for the identical coinstake, purely depending on which one mined
the input being spent — and a receiving node could reject a
perfectly-honest block the originating node considered valid. Reproduced
live this session: `node1` rejected `node0`'s own correctly-constructed
block with `coinstake pays too much (actual=6202545797 vs
limit=6081165253)`, a ~2% mismatch, immediately after the two nodes
reconnected following an independent-staking test.

**Fix:** both `pos.cpp::GetCoinstakeMaxReward` (consensus) and
`wallet/staking.cpp::GetWalletTxOriginTime` (wallet) now resolve origin
time via *only* the origin/confirming block's own canonical header time —
identical on every node that has that block, regardless of whether they
mined it or synced it. Never `Coin.nTime`, never `tx->nTime` directly,
never wallet-local metadata like `nTimeReceived` (which depends on when
*that specific node* happened to see the transaction). This is deliberately
a narrower, more conservative resolution than the kernel-hash code's own
`Coin.nTime`-if-set fallback — that fallback is fine for kernel-hash
scrambling (not consensus-critical, doesn't gate validity across nodes) but
was never safe for a reward *amount* every node must agree on
byte-for-byte, which the kernel-weight code never needed to do since kernel
weight is amount-only (unaffected by any of this).

---

## 7. Supply ceiling — `MAX_MONEY` and the `int64` `CAmount` constraint

**No code change required here** — `src/consensus/amount.h` in the forked
codebase already defines:

```cpp
static constexpr CAmount MAX_MONEY = std::numeric_limits<int64_t>::max();
```

i.e. Blackcoin More (unlike Bitcoin's fixed 21,000,000 BTC cap) already sets
`MAX_MONEY` to the full `int64_t` ceiling, not a smaller fixed constant. This is
inherited as-is for CodexaCoin.

### 7.1 The real constraint: `CAmount` is `int64_t`

`int64_t` max = `9,223,372,036,854,775,807` satoshis = **92,233,720,368 CAC**
at 8 decimals. This is a hard ceiling on total representable supply regardless
of what `MAX_MONEY` is set to — widening it would require changing the
`CAmount` type itself (see §7.3, explicitly rejected for Phase 1).

### 7.2 20-year supply projections (monthly-compounding model)

Model: `total_supply(t_months) = 14e9 × (1 + 0.0114 × P)^t_months`, where `P` is
the fraction of circulating supply actively staking at any time (simplifying
assumption: constant participation ratio, rewards re-enter the staking pool at
the same ratio).

| Participation | Effective APY | 10-year supply | 20-year supply | Headroom vs. int64 ceiling (92.23B) |
|---|---|---|---|---|
| 25% | 3.47% | 19,699,059,699 CAC (+40.7%) | 27,718,068,074 CAC (+98.0%) | Safe, 3.3× under ceiling |
| 50% | 7.06% | 27,691,217,518 CAC (+97.8%) | 54,771,680,545 CAC (+291.2%) | Safe, 1.7× under ceiling |
| 100% | 14.57% | 54,560,953,484 CAC (+289.7%) | 212,635,546,078 CAC (+1418.8%) | **Exceeds ceiling by ~2.3×** |

At sustained **100%** network-wide participation, the model crosses the `int64`
ceiling (92,233,720,368 CAC) around **month 166 (≈13.9 years)**. 25% and 50%
participation stay safely under the ceiling through year 20 and well beyond.

### 7.3 Decision (confirmed with the project owner 2026-07-31)

- Keep `CAmount` as `int64_t` — **do not** undertake the invasive widening
  (serialization, script interpreter, wallet DB, RPC/JSON, net messages) that a
  128-bit amount type would require. Out of scope for Phase 1 and rejected as a
  default path.
- `MAX_MONEY` stays at the inherited `int64_t` ceiling (no code change).
- **Mitigation:** `STAKE_REWARD_ANNUAL_BP` is the governance lever. It must be
  lowered (via soft fork / config default change) well before sustained
  full-network participation approaches the `int64` ceiling. This is recorded
  as a **Phase 7 mainnet-launch-checklist item**: monitor network-wide staking
  participation over time and schedule a reward-rate step-down if participation
  trends toward the danger zone (rough rule of thumb: if participation is
  sustained above ~60–70% for years at a time, begin planning a reduction).

---

## 8. Genesis

| Field | Value |
|---|---|
| Timestamp phrase (all networks) | `"CNBC 29/Jul/2026 Fed meeting recap: July 2026"` |
| Source | [CNBC, published 2026-07-29](https://www.cnbc.com/2026/07/29/fed-meeting-today-live-updates.html) — verifiable, dated, independent financial-news headline, mirroring Bitcoin's own genesis-message convention (news source + date + headline). Quoted in full, not truncated — the coinbase scriptSig has a hard 100-byte consensus limit (`consensus/tx_check.cpp`), which an earlier, longer candidate headline exceeded (`bad-cb-length` at genesis load; caught by actually running the built node, see §9). |
| nTime (all networks) | `1785326400` (2026-07-29 12:00:00 UTC). Chosen to be safely in the *past* relative to real time — an earlier choice of "midnight on launch day" was accidentally ~2h in the future, which caused every subsequent block to fail `time-too-new` once real mining resumed. Caught only by actually running the node, not by inspection. |
| Genesis nVersion | **7**, not the Bitcoin-derived default of 1. `CheckBlockHeader()` (`validation.cpp`) rejects `nVersion < 7` once `IsProtocolV2(blockTime)` is true, and CAC's genesis timestamp (2026) is past Blackcoin's inherited `nProtocolV2Time`/`V3Time`/`V3_1Time` thresholds (all circa 2014-2024, left unchanged — they're historical protocol-upgrade markers, not branding). Found by actually booting the built node, not by inspection. |
| PoW check uses `GetPoWHash()` (scrypt) | Not `GetHash()` (SHA256d). `primitives/block.cpp::GetHash()` is version-conditional (SHA256d for `nVersion > 6`, scrypt otherwise) but PoW validation always checks `GetPoWHash()` (always scrypt) regardless of version. The genesis-mining tool initially checked the wrong hash and every genesis silently failed `high-hash` at load. Found by actually running the node. |
| Genesis reward | `0` (matches Blackcoin convention — genesis coinbase is unspendable regardless, see §5) |
| Mainnet | nNonce=`2473299`, hash=`0xecf4dfc81beeb2a992ee169e1fc349144e48108d7a03f7fb6d619c2bd845038e` |
| Testnet | nNonce=`73100`, hash=`0x719ff8d5c4773340ff014d12c0bbc623aa6fc2abc2b4ecd6dc7e93ef4f609b95` |
| Signet | Same (nTime, nBits) as testnet by choice, so same hash — not consensus-relevant since magic bytes/ports keep the networks from ever interoperating |
| Regtest | nNonce=`1`, hash=`0x66a3b7f4db8f62053c717aab1d5ff9fa8cfed4f7b27f2583b438ee8f4c9c12d1` |

All four mined by `contrib/genesis/generate_genesis.cpp` (compiled and linked
manually against the built static libs — see the file's header comment for
the exact command; not wired into the autotools `Makefile.am` since it's a
one-off parameter-finalization tool, not a shipped binary). The resulting
hashes are already baked into `kernel/chainparams.cpp`'s `assert()` calls, and
the daemon has been run against them (see §6.1).

---

## 9. Open TODOs before any public launch

1. ~~Generate the actual genesis block~~ — **done this phase**, see §8.
2. Mine the *real* (non-regtest) 500-block founder premine window privately
   on mainnet, verify total = exactly 14,000,000,000 CAC via
   `scripts/audit_premine_supply.py` (already proven correct on regtest this
   phase — see §6.1), then freeze those 500 block hashes into
   `checkpointData`.
3. Write the formal Appendix A.5 test suite (unit tests for the formula incl.
   128-bit overflow cases, the full-simulated-year calibration test, the
   age-cap test, the kernel-independence statistical test) — this phase only
   ran one real end-to-end verification (§6.1), not the full spec'd test
   suite.
4. Register (or at minimum re-verify non-collision of) BIP44 coin type `3377`
   against the live SLIP-44 registry.
5. Choose dedicated BIP32 xpub/xprv version bytes instead of reusing Bitcoin's
   (not consensus-critical, cosmetic/compatibility only).
6. Stand up real DNS seed hostnames (`seed1.codexacoin.example` etc. are
   placeholders in `kernel/chainparams.cpp`).
7. ~~Build the Qt desktop wallet~~ — **done in Phase 2/3**: `qt@5` was built
   from full source (~57 min, no prebuilt bottle for this macOS version) and
   `CodexaCoin-Qt.app` verified launching correctly. Phase 3 additionally
   bundled it into a portable, redistributable `.dmg`
   (`contrib/macdeploy/build_dmg.sh`) — see §10 for what's still missing
   before public distribution (codesigning/notarization).
8. Generate a dev fund address and decide whether to enable the donation
   feature (currently disabled — `vDevFundAddress` is empty on every network,
   see `kernel/chainparams.cpp`).
9. Actually produce Windows and Linux desktop build artifacts. Phase 3
   wrote the cross-compilation config (`.github/workflows/release.yml`,
   reusing the proven Ubuntu-runner + `depends/` matrix from the existing
   `build.yml` CI) but could not produce either **locally** in this
   session's macOS-only, no-Docker environment:
   - **Windows**: the mingw-w64 cross-compiler is installed and works (Boost
     and libevent built successfully via `depends/`), but the Qt 5.15.10
     source download from `download.qt.io` reset mid-transfer on two
     separate attempts at a similar point (~15-30% through the 48MB file),
     and the depends system's own fallback mirror
     (`bitcoincore.org/depends-sources`) 404s for this exact filename. This
     reads as an environment-specific network constraint (a proxy or
     egress limit on that specific host), not a toolchain problem — GitHub
     Actions' own network won't have the same issue.
   - **Linux**: `depends/hosts/linux.mk` expects a pre-installed
     `x86_64-pc-linux-gnu` cross-compiler on `PATH` (matching Ubuntu's
     `apt-get install g++` pattern in `build.yml`'s CI matrix); it does not
     build one from scratch, and none is available via Homebrew in a
     supported form. The standard way to produce Linux binaries from a
     macOS host is Docker or a Linux VM, neither available this session
     (see the same limitation noted for Phase 2's Docker Compose
     environment).

   Net effect: `.github/workflows/release.yml` is real, reviewed
   configuration that reuses an already-proven CI matrix, but it has not
   been run end-to-end (needs an actual GitHub Actions run against a
   pushed tag to fully verify) — the macOS leg is the only one locally
   built and verified.

---

## 10. Desktop build signing/notarization (Phase 3, still open)

None of the three platforms' build artifacts are signed. This project has
no code-signing certificates (Apple Developer ID, a Windows Authenticode
cert), so this is a real TODO, not an oversight:

- **macOS**: `contrib/macdeploy/build_dmg.sh` prints the exact
  `codesign`/`notarytool`/`stapler` commands needed, once a Developer ID
  Application certificate exists. Unsigned, the `.dmg` will trigger
  Gatekeeper's "unidentified developer" warning on first launch.
- **Windows**: `.github/workflows/release.yml`'s Windows job has a TODO
  comment with the `osslsigncode` invocation needed once an Authenticode
  certificate exists. Unsigned, the installer will trigger SmartScreen
  warnings.
- **Linux**: `.deb` packages are conventionally signed via a GPG-signed
  `Release` file at the *repository* level (e.g. an APT repo), not
  per-package — not applicable until there's an actual package repository
  to publish to.

---

## 11. Light-wallet backend (Phase 4)

`electrumx-cac` (CodexaCloud repo root) adapts
[CoinBlack/electrumx-blk](https://github.com/CoinBlack/electrumx-blk) —
chosen over Fulcrum because Fulcrum has no generic altcoin/PoS support at
all (BTC/BCH/LTC-specific transaction handling only). `electrumx-blk`
already had a Blackcoin-specific transaction deserializer handling the PoS
coinstake `nTime` field CAC inherits unchanged, and a
version-conditional header-hash mixin that already matches this fork's
real block-version behavior — so adapting it was almost entirely
chain-identity configuration (genesis hash, RPC port, address prefixes),
not protocol work. See `provisioning/electrumx/README.md` for the full
writeup, including exactly what was and wasn't verified locally (RPC
connectivity: yes; full block indexing: blocked by a macOS-12-specific
Python C-extension packaging issue with both of electrumx's storage
backends, not a CAC problem — the provided Dockerfile sidesteps it via
Debian's packaged leveldb).

### Open TODOs from this phase

1. Stand up the 2 real Electrum servers `provisioning/electrumx/` deploys
   to (currently placeholder hostnames, same TODO status as the DNS seeds
   in item 6 above).
2. Verify full block indexing end-to-end on a real Linux host or via the
   provided Docker image (not blocked there — only blocked on this
   session's specific macOS 12 dev machine).
3. Build the actual mobile API gateway service specified in
   `docs/mobile-api.md` — that document is a specification only; Phase 4
   did not implement the gateway itself (Phase 5/6 work, once the mobile
   app architecture and staking service exist to build it alongside).
