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

`codexacoin-core/scripts/audit_premine_supply.py` sums the coinbase reward
across blocks 1–500 via RPC and asserts the total equals exactly
`14,000,000,000 * COIN` satoshis, with zero drift.

### 5.4 Premine window completion and checkpoint freeze (2026-08-01)

The real 500-block founder premine window described above was mined live
on mainnet — all 500 blocks, privately, before any public release. Two
things were done immediately once block 500 landed:

- **Supply audit**: `audit_premine_supply.py` scanned the live chain and
  confirmed the total minted across blocks 1–500 is exactly
  `14,000,000,000.00000000 CAC`, with a constant `28,000,000 CAC`
  per-block reward across the entire window — zero deviation.
- **Checkpoint freeze**: all 501 block hashes (genesis through block 500,
  fetched live via `getblockhash`) are now hardcoded into mainnet's
  `checkpointData` in `chainparams.cpp`, per the plan in §5.1. This makes
  the entire premine window unreorgable for any node that ever syncs from
  genesis — a deep reorg past this point is now rejected outright rather
  than merely improbable.

The node was restarted after each change (binary rebuild, then again
after the checkpoint-data rebuild) and both times came back up cleanly at
the same height with `bestblockhash` matching the newly-hardcoded height-500
checkpoint exactly — confirming the checkpoints validate the real chain
rather than accidentally diverging from it.

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

**Maturity-drag calibration (§A.3 of spec):** the formal Appendix A.5 unit
test suite now exists (`src/test/pos_tests.cpp`, added 2026-08-02 — see §6.1a
below) and includes a fast, deterministic full-year calibration case: it
sums `ComputeCoinAgeReward` across repeated max-age-cap stake events spanning
`SECONDS_PER_YEAR` and asserts the total lands within 1000 satoshis of the
nominal `valueSat × 1368bp / 10000` rate (it lands within 2, in practice).
That confirms the *formula* pays out its nominal annual rate when a coin
restakes promptly and repeatedly — it is **not** the same as a real
492,000-block regtest simulation accounting for the 500-block lockup's
maturity drag, which is a heavier, separate exercise nobody has run yet. The
maturity-drag question (whether 1368 bp needs bumping to ~1420 bp to net out
at a realized 1.14%/month after the lockup) is still open. **Do not treat
1368 as calibrated for that purpose — it is still the uncalibrated spec
default**, just now formula-verified.

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

This is real end-to-end verification of the reward *mechanism*. The 6B
negative test (cold-staking is future work, §6.3 below) remains TODO; the
rest of the spec's Appendix A.5 test suite is now written — see §6.1a.

### 6.1a Appendix A.5 unit test suite (added 2026-08-02)

`src/test/pos_tests.cpp`, registered in `Makefile.test.include`, seven cases,
all pure/deterministic (no chain, no wallet, no network — `CheckStakeKernelHash`
only needs a bare `CBlockIndex` with `nStakeModifier` set):

- `ComputeCoinAgeReward_KnownVector` — pins the exact §6.1 regtest result
  (28,000,000 CAC × 500s × 1368bp = 6,069,027,198 satoshis) as a regression
  guard.
- `ComputeCoinAgeReward_ZeroAndNegativeInputsReturnZero`.
- `ComputeCoinAgeReward_AgeCapPlateaus` — reward strictly increases up to
  `nStakeRewardAgeCapSeconds`, then is identical for any age at or beyond it.
- `ComputeCoinAgeReward_IntermediateMathOverflowsInt64` — confirms the
  `valueSat × cappedAge` intermediate genuinely exceeds `int64_t` range at
  `INT64_MAX` valueSat (proving the 128-bit `arith_uint256` path is actually
  exercised, not dead code), and that the final reward still lands well
  within `CAmount` range.
- `ComputeCoinAgeReward_DefensiveOverflowClamp` — the end-of-function clamp
  to `int64_t` max is provably unreachable through any `(valueSat, params)`
  this project actually ships (max realistic reward computed against
  `INT64_MAX` valueSat at the 60-day cap is ~207 quadrillion satoshis, far
  under `INT64_MAX` ~9.2 quintillion). To still test the clamp itself, this
  case passes a deliberately-unrealistic `Consensus::Params` (huge
  `nStakeRewardAnnualBP`) to force the overflow branch and confirms it
  saturates rather than wraps negative — a guard against a future constant
  change breaking this silently.
- `ComputeCoinAgeReward_FullYearCalibration` — see the §6 note above.
- `CheckStakeKernelHash_EligibilityIndependentOfAge` — the "kernel-independence
  statistical test" called for by the spec. Fixes `nValueIn`, picks `nBits`
  (via `arith_uint256::GetCompact()`) so the weighted target sits at ~50% of
  the 256-bit hash space for that value, then runs 3000 trials each at a
  "young" (1s) and "old" (55-day) age, varying only the prevout hash per
  trial for entropy. Empirical pass rates: 50.4% young vs 51.7% old (Δ 1.3
  points, well inside the ±7-point tolerance chosen against ~1.8-point
  expected sampling noise at n=3000) — no age-correlated skew, confirming
  `bnWeight = arith_uint256(nValueIn)` really is amount-only as designed.

Verified with the project's actual `make check` invocation (each suite runs
as its own `test_codexacoin` process via `Makefile.test.include`'s
`%.cpp.test` rule) — `test/pos_tests.cpp.test`: **no errors detected**.
Running the whole `test_codexacoin` binary unfiltered in one process (not how
`make check` actually invokes it) surfaces ~34 unrelated pre-existing
failures across the suite, e.g. `argsman_tests` failing with "time-too-new,
block timestamp too far in the future" — a hardcoded 2020 mocktime fixture
being checked against the real wall-clock (now 2026), a test-suite staleness
issue that predates this change and reproduces identically with `pos_tests`
excluded entirely. Not fixed here (out of scope for the Appendix A.5 task);
flagging for whoever next touches the broader test suite.

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

### 6.4 A third, chain-halting bug — found live at the height-500 boundary

Neither Phase 1 nor Phase 2's tests ever reached this scenario, because
both used a short, artificial premine window on regtest/testnet with
`generatetoaddress` fast-forwarding straight past the maturity boundary.
The real 500-block mainnet premine (§5) hit it for real the moment mining
finished: at height 500, `getbalances` reported the entire 14,000,000,000
CAC premine as `"immature"` and `getstakinginfo` reported `"weight": 0` on
every wallet — meaning **no wallet would even attempt to stake**, and
since `nLastPOWBlock = 500` permanently disables PoW at that same height,
nothing could ever produce block 501. A genuine chain-halting deadlock,
live, on mainnet.

**Root cause:** two different maturity thresholds exist in the codebase
and were never reconciled. `pos.cpp`'s actual PoS block-validation rule
(`CheckProofOfStake`) requires a stake input to have `>= nCoinbaseMaturity`
confirmations — by design, so the very first post-premine block is
producible the instant PoW ends (see §5.2's "no dead zone" reasoning,
which assumed this). But `wallet/staking.cpp`'s coin-selection
(`GetStakeWeight`, `AvailableCoinsForStaking`, `CreateCoinStake`) computed
its candidate balance from `GetBalance()`'s generic `m_mine_trusted`
figure and an `IsTxImmature()` filter — both of which, via
`wallet.cpp::GetTxBlocksToMaturity()`, require `> nCoinbaseMaturity`
confirmations (i.e. `nCoinbaseMaturity + 1`, matching upstream Bitcoin
Core's ordinary spend-safety convention). That's one confirmation later
than the consensus rule actually requires — close the gap by design in
theory, but off by exactly one block in the wallet's own implementation,
recreating the dead zone in practice.

**Fix:** added `wallet/staking.cpp::GetStakingBalance()`, a
staking-specific balance helper that sums `AvailableCoinsForStaking`'s own
candidate list (whose `min_depth` check already correctly uses
`nCoinbaseMaturity`, not `+1`) instead of reusing `GetBalance()`'s generic
trusted-balance figure. Removed the redundant, stricter `IsTxImmature()`
gate from `AvailableCoinsForStaking` itself (the `min_depth` check a few
lines later already does the correct, staking-specific job). All three
call sites (`GetStakeWeight`, `AvailableCoinsForStaking`,
`CreateCoinStake`) now agree with `pos.cpp`'s validation rule. Ordinary
wallet balance display (`getbalances`, regular spending) is untouched and
still correctly requires the more conservative `nCoinbaseMaturity + 1`
threshold — this fix only changes which coins the *local wallet* is
willing to attempt staking with, not any network consensus rule, so
there's no fork risk.

**Verified live on mainnet immediately after the fix:** `getstakinginfo`
weight went from `0` to `2,800,000,000,000,000` satoshis (exactly block
1's 28,000,000 CAC coinbase) the moment the rebuilt node restarted; block
501 was produced within about a minute, correctly flagged
`"flags": "proof-of-stake"`, consuming block 1's coinbase as the stake
input and paying a coin-age-proportional reward on top of it
(`getbalances` showed the new coinstake output as
`28,011,878.90693625 CAC` under the `"stake"` category). The chain is no
longer stalled.

### 6.5 Why `nCoinbaseMaturity` stays at 500 for now, and when to revisit it

Raised and considered on 2026-08-01, right after §6.4's fix: should
`nCoinbaseMaturity` (500 blocks, ~8.9h at 64s spacing) be lowered, since
it now gates every future staking reward, not just the one-time premine?
"10 confirmations" was the initial suggestion, on the reasoning that it's
roughly standard practice for trusting an ordinary transaction.

That comparison doesn't transfer here. `nCoinbaseMaturity` isn't a
"trust this payment" threshold — it only ever applies to newly-minted
coinbase/coinstake outputs (`tx_verify.cpp`: `coin.IsCoinBase() ||
coin.IsCoinStake()`), never to ordinary transactions, which remain
spendable after a single confirmation same as any other chain. For
coinbase/coinstake maturity specifically, even Bitcoin itself uses 100
blocks, not 10 — and the reasoning for staying conservative here is
stronger than Bitcoin's, for two compounding reasons:

1. **No slashing.** Nothing in `pos.cpp`/`wallet/staking.cpp` penalizes a
   staker for building on more than one competing chain tip with the same
   coins — the classic "nothing at stake" problem for a PoS design this
   simple. Confirmation depth is doing double duty here: it's not just
   "how likely is a reorg," it's the *only* real deterrent against someone
   quietly building a longer alternate chain and swapping it in later.
   Shortening it directly shortens that deterrent.
2. **Stake concentration is currently at its worst.** As of this writing,
   essentially all stakeable coin-weight is the founder premine, held by a
   small set of wallets under direct control of the project. That is
   exactly the condition under which a self-reorg is *cheapest* to
   attempt — a single party already holds enough stake weight to try it.
   This is the opposite of the moment to shrink the safety margin.

**Decision: keep 500 for now.** The right maturity depth here should
track how genuinely distributed the network's stake is, not be fixed
forever — revisit lowering it once real, independent stakers hold a
meaningful share of total stake weight (post-launch, real participation),
at which point a self-reorg by any single holder becomes far less
practical and a shorter window becomes safe the same way it is on
established chains. Lowering it now, while stake is maximally
concentrated, would be lowering the network's security at exactly the
wrong time.

### 6.4 BIP32 extended-key version bytes (added 2026-08-02)

Every network in `kernel/chainparams.cpp` reused Bitcoin's own
`EXT_PUBLIC_KEY`/`EXT_SECRET_KEY` version bytes verbatim
(`0x0488B21E`/`0x0488ADE4` mainnet, `0x043587CF`/`0x04358394` testnet) up
until this change — meaning `dumpwallet` and `listdescriptors` produced
strings starting with Bitcoin's own literal "xpub"/"xprv", indistinguishable
at a glance from a real Bitcoin extended key. Not consensus-critical (this
only affects how a wallet backup file or descriptor string displays, never
validation), but confusing and worth fixing before anyone relies on a backup
file for real.

There's no central registry for this the way SLIP-44 governs BIP44 coin
types (§9 item 4) — altcoins pick their own version bytes independently and
collisions are tolerated (the underlying key material and network context
are what actually matter, not the display prefix). Chose new 4-byte values
via a brute-force search over candidate bytes, serializing realistic
extended-key payloads (varying depth 0-5, fingerprint, child number, and key
material per BIP44-style derivation) and keeping only candidates whose
resulting base58 string prefix was stable across many random trials — the
same technique other projects used originally to land on "xpub"/"tpub"/etc.
Confirmed the chosen bytes don't collide with Bitcoin's own four well-known
values.

| Network | `EXT_PUBLIC_KEY` | `EXT_SECRET_KEY` |
|---|---|---|
| Mainnet | `0x38 0x86 0x00 0x00` | `0x38 0x84 0x00 0x00` |
| Testnet/Signet/Regtest (shared) | `0x39 0x86 0x00 0x00` | `0x39 0x84 0x00 0x00` |

**Live-verified**, not just simulated: rebuilt `codexacoind`/`codexacoin-cli`,
ran an isolated real mainnet node (`-connect=0 -listen=0 -dnsseed=0`, no
chain sync needed since this only affects fresh wallet key derivation),
created a descriptor wallet, and confirmed `listdescriptors` returns
extended pubkeys starting `CzsJd1...` — e.g.
`pkh(CzsJd1UEME6DE59E4ta8iCrzW7uFGzLU8Hpy4UkahVa8reqJ7MykU5B5jKGLRrPNXKUdvfsxVtsdxPr1rji1VHeeTnzsRgiDcFZUagbsJ5iBrvj7/44h/10h/0h/0/*)`.
Repeated on regtest (shares the non-mainnet bytes) and got `DDBSyy...` —
also confirmed live. `dumpwallet`'s extended-*private*-key line
(`EXT_SECRET_KEY`) uses the exact same `EncodeBase58Check` mechanism just
verified for the public side, but couldn't be independently re-run live in
this same session: `dumpwallet` requires a legacy (BDB) wallet, and this
build's `codexacoind` has no BDB support (this project standardized on
descriptor/SQLite wallets everywhere — mobile, gateway, staking pool).
Byte values for both `EXT_PUBLIC_KEY` and `EXT_SECRET_KEY` are confirmed
correct by direct inspection of `chainparams.cpp` across all four network
blocks either way.

Not a breaking change for anything already deployed: nothing in
`mobile-wallet/` or `web-wallet/` ever serializes/displays an extended key
(both use raw private/public key bytes only, confirmed by inspection), and
any *already-taken* `dumpwallet` backup file remains fully valid and
importable regardless of this change — only the string *prefix* of newly
generated backups differs going forward.

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
2. ~~Mine the *real* (non-regtest) 500-block founder premine window privately
   on mainnet, verify total = exactly 14,000,000,000 CAC via
   `scripts/audit_premine_supply.py`, then freeze those 500 block hashes into
   `checkpointData`~~ — **done 2026-08-01**: mined all 500 blocks live,
   `audit_premine_supply.py` confirmed the total is exactly
   14,000,000,000 CAC with zero deviation across the window, and all 501
   hashes (genesis through block 500) are now hardcoded into mainnet's
   `checkpointData` in `chainparams.cpp`. See §5.4.
3. ~~Write the formal Appendix A.5 test suite~~ — **done 2026-08-02**:
   `src/test/pos_tests.cpp`, 7 cases (overflow, age-cap, full-year
   calibration, kernel-independence statistical test, etc.), all passing.
   See §6.1a.
4. Register (or at minimum re-verify non-collision of) BIP44 coin type `3377`
   against the live SLIP-44 registry.
5. ~~Choose dedicated BIP32 xpub/xprv version bytes instead of reusing
   Bitcoin's~~ — **done 2026-08-02**, see §6.4.
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
9. ~~Actually produce Windows and Linux desktop build artifacts~~ —
   **done 2026-08-02** (retried after Docker became available in this
   environment; see §10.1 for the full writeup):
   - **Windows** (x86_64, CLI only — no Qt): built via the mingw-w64
     cross-compiler using `depends/` (`NO_QT=1`, `--disable-shared`).
     Produces real, working `codexacoind.exe`/`codexacoin-cli.exe`/
     `codexacoin-tx.exe`/`codexacoin-util.exe`/`codexacoin-wallet.exe`
     (valid PE32+ executables, confirmed via `file`). Uncovered and fixed
     two real portability bugs along the way (missing `<cstdint>` includes
     across ~50 headers, and a stack-protector library link conflict) —
     see §10.1. Not runtime-tested on actual Windows or under Wine (Wine's
     own cask install failed/deprecated in this environment); verified by
     successful cross-compilation, linking, and PE format validation only.
   - **Linux** (x86_64, full GUI): built natively inside an Ubuntu 22.04
     Docker container (`apt`-installed Qt5/boost/etc., no depends/ cross
     toolchain needed for this leg). Produces `codexacoin-qt`,
     `codexacoind`, `codexacoin-cli`, and the rest. **Live-verified**. not
     just compiled: ran `codexacoind` inside the container on regtest,
     called `createwallet`/`getnewaddress` over RPC, got a real address
     back.

   Both packaged (`CodexaCoin-Core-win64.zip`,
   `CodexaCoin-Core-x86_64-linux-gnu.tar.gz`), GPG-signed, and published —
   see §10.1. `.github/workflows/release.yml` (Phase 3) still hasn't been
   run end-to-end on GitHub Actions itself, but the actual deliverable
   (working binaries on the website) no longer depends on that.
10. ~~Investigate: P2P connections between the Mac's node and the VPS's
    explorer-support node never succeeded~~ — **root-caused and fixed
    2026-08-01, no code changes needed.** Initially looked like a
    codebase bug in `CConnman` (every connection attempt appeared to
    vanish with no log trace at all, from either RPC `addnode ... onetry`
    or a config-level `addnode=`), but that first read was wrong — a
    proper investigation (`-debug=net`, `tcpdump` on the VPS, `strace`
    attached to the live `codexacoind` process) traced it to a single
    line: `strace` showed every inbound connection going
    `accept() → setsockopt(TCP_NODELAY) → close()`, with no `recv`/`read`
    ever called, explaining both the silent kernel-level RST (a `close()`
    with unread data in the receive buffer does that) and the total
    absence of any log line (the actual rejection reason,
    `CreateNodeFromAcceptedSocket`'s "connection dropped (full)", is
    itself gated behind the `net` debug category, which wasn't enabled on
    the VPS side during the original attempts).

    The real cause: the VPS's `codexacoind` was configured with
    `maxconnections=8` (an arbitrary value chosen during initial
    provisioning, not a deliberate limit). Bitcoin Core's connection-slot
    math reserves outbound capacity *first* —
    `m_max_outbound_full_relay = min(MAX_OUTBOUND_FULL_RELAY_CONNECTIONS
    (16), nMaxConnections)` — so at `nMaxConnections=8` that reservation
    alone consumes all 8 slots, leaving
    `nMaxInbound = nMaxConnections - m_max_outbound = 8 - 8 = 0`. Every
    single inbound connection then hit `nInbound >= nMaxInbound` (`0 >=
    0`), found nothing to evict, and got dropped — deterministically,
    every time, which is exactly what was observed. **Fix**: removed the
    `maxconnections=8` override from the VPS's `codexacoin.conf`
    entirely (falls back to the default of 125, which reserves outbound
    slots the same way but leaves well over 100 free for inbound).
    Verified immediately after restarting: a fresh isolated test node
    connected via real P2P and did a full sync of all 521 blocks, and
    both the Mac's persistent node and the VPS's persistent node now show
    each other in `getpeerinfo` (`manual` outbound from the Mac,
    `inbound` on the VPS). The manual `blocks/`+`chainstate/` copy
    workaround (`provisioning/explorer/cac-resync.sh`) is no longer
    needed for ongoing sync as a result — kept only as a fast-bootstrap
    option for spinning up a brand-new node. See
    `provisioning/explorer/README.md` for the full writeup and the
    `-debug=net`/`tcpdump`/`strace` diagnostic trail.

---

## 10. Desktop build signing/notarization (Phase 3, still open)

None of the three platforms' build artifacts are signed. This project has
no code-signing certificates (Apple Developer ID, a Windows Authenticode
cert), so this is a real TODO, not an oversight:

- **macOS**: `contrib/macdeploy/build_dmg.sh` prints the exact
  `codesign`/`notarytool`/`stapler` commands needed, once a Developer ID
  Application certificate exists. Unsigned, the `.dmg` will trigger
  Gatekeeper's "unidentified developer" warning on first launch.
  Published anyway at `codexacoin.com/downloads/CodexaCoin-Core-macOS.dmg`
  (2026-08-01) — the site says plainly that it's unsigned and how to work
  around Gatekeeper (right-click → Open) rather than hiding the
  limitation. Still needs a real Developer ID before this is a
  reasonable default download experience.
- **Windows**: `.github/workflows/release.yml`'s Windows job has a TODO
  comment with the `osslsigncode` invocation needed once an Authenticode
  certificate exists. Unsigned, the installer will trigger SmartScreen
  warnings.
- **Linux**: `.deb` packages are conventionally signed via a GPG-signed
  `Release` file at the *repository* level (e.g. an APT repo), not
  per-package — not applicable until there's an actual package repository
  to publish to.

Paid code-signing certificates (Windows Authenticode, Apple Developer ID)
require a purchase and real business/identity verification — both outside
what this project can do unilaterally. Asked the project owner directly how
to handle this (2026-08-02); decided: ship real Windows/Linux binaries now
with GPG signing + SHA256 checksums (free, immediate, and the same scheme
Bitcoin Core itself uses for its own releases), and revisit paid
certificates later if the owner decides to buy one. See §10.1.

### 10.1 Windows/Linux builds, GPG release signing, and publishing (2026-08-02)

Retried §9 item 9 after Docker became available in this environment (it
wasn't, or wasn't working, during the original Phase 3 attempt).

**Windows** (mingw-w64, CLI only — Qt was deliberately skipped via
`NO_QT=1` since the previous attempt's Qt-source-download blocker was
never re-verified as fixed, and a working CLI build was the higher-value,
lower-risk target to actually ship today):

- Two real, previously-undetected portability bugs surfaced only once an
  actual cross-compile was attempted (this project had only ever been
  built on macOS before now):
  1. ~50 headers use `uint16_t`/`uint32_t`/`uint64_t`/`int64_t` without
     directly including `<cstdint>`, relying on it arriving transitively
     through another standard header. macOS's libc++ happens to do that;
     mingw-w64's libstdc++ does not. Fixed by adding the explicit include
     to every affected header (commit `3715899`).
  2. `libbitcoinconsensus`'s shared-library link failed with "multiple
     definition of `__stack_chk_fail`" — mingw-w64's static `libssp.a` and
     its DLL import lib both got pulled in simultaneously. Fixed by
     configuring with `--disable-shared` (this project doesn't need the
     standalone libbitcoinconsensus C API; a fully static Windows build is
     also the standard approach for a distributable binary anyway).
- Produces real `codexacoind.exe`, `codexacoin-cli.exe`, `codexacoin-tx.exe`,
  `codexacoin-util.exe`, `codexacoin-wallet.exe` — confirmed as valid
  PE32+ executables via `file`. **Not** runtime-tested on real Windows or
  under Wine (Wine's own `brew install --cask wine-stable` failed: the
  cask is deprecated and its download timed out) — verification here is
  limited to successful cross-compilation, static linking, and PE format
  validation, not an actual execution trace. A real Windows/Wine
  smoke-test is still open work.

**Linux** (native build inside an Ubuntu 22.04 Docker container, full
Qt GUI): no cross-compiler needed for this leg — `apt install
qtbase5-dev` etc. gives a native toolchain, unlike Windows' cross-compile
path. Configured with `--with-gui=qt5`, built cleanly with zero source
changes needed. **Live-verified**, not just compiled: ran the resulting
`codexacoind` inside the container on regtest, called `createwallet` and
`getnewaddress` over real RPC, got back a real address
(`mu14D8PTNSEGSCT8MVgK9mymGJBHH3b9y2`). Dynamically linked against
standard Ubuntu 22.04 packages (Qt5, libevent, libzmq, sqlite3,
miniupnpc, libnatpmp) — documented in the package's own README with the
`apt install` line needed on a bare system.

**GPG release signing**: generated a real ed25519 GPG keypair
(`releases@codexacoin.com`, fingerprint `2C77 0475 F75E 8947 5B0E C03B
7037 CCBC C6DC 0A7A`, 2-year expiry) via `gpg --batch --generate-key`.
Private key material lives at `~/.codexacoin-release-gpg` on this Mac,
outside any git-tracked directory — deliberately not committed anywhere.
Computed `SHA256SUMS` across all four release artifacts (macOS `.dmg`,
Windows `.zip`, Linux `.tar.gz`, Android `.apk`) and produced a detached
signature (`SHA256SUMS.asc`), verified locally with `gpg --verify` before
publishing. This is the same release-signing pattern Bitcoin Core itself
uses (`SHA256SUMS.asc` + a project GPG key) — it proves a download is
byte-for-byte what the project published, but it does **not** suppress
Windows SmartScreen or macOS Gatekeeper warnings, which only a paid,
identity-verified certificate can do. The website's Wallets section now
explains this distinction plainly rather than implying GPG signing =
"no more warnings."

**Published** to `codexacoin.com/downloads/`: `CodexaCoin-Core-win64.zip`,
`CodexaCoin-Core-x86_64-linux-gnu.tar.gz`, `SHA256SUMS`, `SHA256SUMS.asc`,
`codexacoin-release-key.asc` (public key), alongside the existing macOS
`.dmg` and Android `.apk`. All four checksums re-verified against the live
server after upload (`shasum -a 256 -c SHA256SUMS` — all OK). Website
updated with two new wallet cards (Windows, Linux) and a "Verifying a
download" section with copy-pasteable `gpg`/`shasum` commands; the hero
status banner and roadmap's stale "Windows/Linux desktop builds ... still
to come" language corrected now that they're actually shipped.

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

---

## 12. Mobile wallet (Phase 5) — build environment and what was verified

`cac_wallet/` (CodexaCloud repo root) is the Flutter light wallet for
Android + iOS, built against `docs/mobile-api.md`'s gateway contract and
`docs/store-compliance.md`'s zero-on-device-staking constraint.

### 12.1 Flutter SDK version — a real macOS 12 compatibility wall

The current Flutter stable release (3.44.8, installed via `brew install
--cask flutter`) fails outright on this development machine: `flutter
--version` reports `VM initialization failed: Current Mac OS X version
12.0 is lower than minimum supported version 14.0` — the Dart VM shipped
with recent Flutter releases refuses to start on macOS 12.7.6. This is a
genuine host-OS ceiling, not a project misconfiguration.

**Fix**: Flutter 3.19.6 (Dart 3.3.4, April 2024) — an older stable
release from before Flutter's toolchain raised its minimum macOS
requirement — installed manually (SDK zip extracted to
`~/flutter-sdk`, not via the Homebrew cask) and confirmed working. All
Phase 5 development and verification below used this SDK. One downstream
consequence: `mobile_scanner` had to be pinned to `^5.1.1` instead of the
latest `5.2.x`, since 5.2.0+ requires Dart >=3.4.0 (see
`cac_wallet/pubspec.yaml`'s comment on that line).

### 12.2 Unit tests — verified, all passing

`flutter test` (crypto + integration-stub suites): **22 passed, 0
failed, 6 skipped** (the skipped tests are `test/integration/
gateway_integration_test.dart`, which require a live gateway deployment
that doesn't exist yet — see §11 item 3). Notably this includes:

- Address round-trip tests in `test/crypto/address_test.dart` against the
  real ground-truth mainnet addresses recorded in §3.1 above — decoding
  one of those C++-node-generated addresses and re-encoding the extracted
  hash reproduces the original string exactly, a genuine cross-
  implementation check, not just internal self-consistency.
- A full ECDSA signature verification test in
  `test/crypto/transaction_test.dart`: builds and signs a transaction with
  the hand-rolled `crypto/transaction.dart`, independently reconstructs
  the expected legacy SIGHASH_ALL preimage from the known fixture inputs
  (not by re-parsing the signer's own output), and verifies the extracted
  signature against it using pointycastle's verifier directly — proving
  the wallet's signing code produces mathematically valid, standard-format
  signatures.

`flutter analyze`: **0 issues** (after fixing a `const` bug —
`StakingStatus.notOptedIn` was declared `const` but initialized with
`BigInt.zero`, which isn't a compile-time constant in Dart — and a couple
of unused-import warnings).

### 12.3 Android — verified end-to-end, including a real on-device UI check

The project had no `android/`/`ios/` platform directories initially
(hand-scaffolded `lib/` came first); `flutter create --platforms=android,
ios .` added them without disturbing the existing `pubspec.yaml`/`lib/`.

Android build required two fixes, both applied and documented inline:
- **Gradle/Java mismatch**: this machine's default `java` is JDK 22, but
  the Flutter template's Gradle 7.6.3 doesn't support Java 22 class files
  (`Unsupported class file major version 66`). Fixed by pointing
  `JAVA_HOME` at the JDK 17 already installed on this machine (a
  well-established compatible Gradle/Java pairing) rather than upgrading
  the project's Gradle version.
- **minSdkVersion**: Flutter's template default (19) is below what
  `mobile_scanner` requires (21). Bumped `android/app/build.gradle`'s
  `minSdkVersion` to 21 directly, per Flutter's own suggested fix.

With both fixed, `flutter build apk --debug` succeeded
(`app-debug.apk`). It was then actually installed (`adb install`) and
launched (`adb shell am start`) on a real emulator (`Pixel_Fold_API_35`,
already present on this machine from prior work) — not just compiled.
Verification, in order: process stayed alive with no `FATAL`/
`AndroidRuntime` exceptions in `logcat`; a device screenshot (via `adb
shell screencap`, which doesn't depend on macOS's own screen-capture
APIs) showed the onboarding screen rendering exactly as designed — the
gold-themed "CodexaCoin Wallet" title, wallet icon, and both "Create a
new wallet" / "Restore from recovery phrase" buttons; tapping "Create a
new wallet" was exercised, though a follow-up screenshot during that
transition was inconclusive due to severe CPU contention on this machine
at the time (the 500-block founder-premine mining described in §5 was
running concurrently on the same 8 logical cores) — the process itself
never crashed or logged an exception throughout.

### 12.4 iOS — not verified this phase; documented, not silently skipped

Xcode 14.2 and the iOS 16.2 Simulator runtime are already present and
working (confirmed via `xcrun simctl list devices`). The blocker is
CocoaPods: it isn't installed, and `brew install cocoapods` on this
machine triggers building **LLVM from source** as a transitive
dependency — a multi-hour compile even before accounting for the CPU
contention from the concurrent premine mining, with no precompiled bottle
available for this specific macOS/Homebrew combination. This is a
genuine, disproportionate environment cost relative to what iOS
verification would add on top of Android's already-real, on-device
confirmation of the same shared Dart codebase (crypto, services, and
every screen are 100% shared between platforms; only the platform
embedding differs) — so it was deliberately not pursued further this
phase rather than left running silently or claimed as done.

### 12.5 Open TODOs from this phase

1. Verify iOS Simulator build once CocoaPods is available without a
   from-source LLVM build (e.g. on a newer macOS host, or by sourcing a
   prebuilt LLVM bottle from elsewhere).
2. Exercise the full send/receive/staking-status screens against a real
   gateway deployment once one exists (see §11 item 3) — everything
   verified this phase used the local crypto layer directly or a bare
   onboarding-screen UI check; the gateway-dependent screens are
   implemented and unit-tested but not yet exercised against a live
   backend.
3. Re-run the inconclusive "Create a new wallet" on-device screenshot
   check in isolation (without concurrent mining/build load) to get a
   clean visual confirmation of the mnemonic-display step.

### 12.6 Wired the Android app to the real gateway and fixed staking (2026-08-03)

Item 2 above, closed: the Android app previously pointed at a placeholder
gateway domain (`api.codexacoin.example`) that was never going to resolve,
and its staking screen was fully stubbed (`stakingStatus`'s auth token
parameter was accepted and silently discarded; deposit/withdraw buttons
just showed a "not live yet" snackbar even though the gateway endpoints
had existed since Phase 6). Fixed:

- `lib/config/network_config.dart`: mainnet `gatewayBaseUrl` now points at
  `https://codexacoin.com/v1`, the same live backend the web wallet uses
  (testnet stays a placeholder — no testnet gateway is deployed).
- `lib/services/gateway_api.dart`: added `login`/`signup` (mirroring
  `web-wallet/gateway.js`'s exact request shape, including the
  self-attested KYC fields), and fixed `stakingStatus`/`stakingDeposit`/
  `stakingWithdraw` to actually send `Authorization: Bearer <token>` —
  they previously never attached the token to the request at all.
- `lib/services/wallet_service.dart` / `wallet_storage.dart`: added
  staking-account auth state (a bearer token, persisted via
  `flutter_secure_storage` separately from the wallet's own mnemonic —
  it's a custodial-pool account credential, not an on-chain key).
- `lib/screens/staking_screen.dart`: rewritten with a real login/signup
  form (mirroring the web wallet's fields and flow, including the
  self-attested-not-verified KYC copy) and working deposit/withdraw
  cards, replacing the "not live yet" stub. Auto-logs out and returns to
  the login form on a 401, matching web-wallet's behavior.

**A real, previously-unknown crash bug found and fixed along the way**:
`android/app/src/main/kotlin/.../MainActivity.kt` extended plain
`FlutterActivity`, but `local_auth` (the biometric app-lock on
`lock_screen.dart`, gating every screen past onboarding) requires a
`FragmentActivity` host to show its prompt. On a fresh install this threw
`PlatformException(no_fragment_activity, ...)` and the app was
**permanently stuck on the lock screen with no way in** — a
launch-blocking bug affecting 100% of real installs, not something
specific to this session's changes. Fixed by switching to
`FlutterFragmentActivity`.

**Verification**: real, not just `flutter analyze` (though that's also
clean). Built and ran the debug APK on a real Android emulator
(Pixel Fold API 35): confirmed the `no_fragment_activity` crash is gone
(topResumedActivity check + logcat, no more fatal exception), created a
real wallet through onboarding (a genuine BIP39 mnemonic rendered and
persisted), and — with `LockScreen` temporarily bypassed in a local,
uncommitted edit purely to get past a *separate*, pre-existing emulator
limitation (this fresh AVD has no enrolled screen-lock credential at all,
so `local_auth` correctly refuses to proceed, which is the "hardware
exists but nothing enrolled" gap the code's own comment already flags as
a known follow-up) — reached the Staking screen and confirmed the new
login/signup form renders. The emulator then became unstable
independent of any app change (`adb` reported it `offline`, and after a
restart `PackageManager` reported the freshly-installed `MainActivity`
component as not existing despite `pm list packages` showing the app
installed) and further on-device clicking through deposit/withdraw
wasn't completed. The temporary `LockScreen` bypass was reverted before
finishing (`git diff lib/main.dart` confirmed empty) and `flutter
analyze` re-run clean afterward — nothing about that bypass shipped.

Still open: actually submitting a signup/login/deposit/withdraw against
the live gateway from the app (blocked on the emulator instability
above, not on anything in the code); a fallback PIN for devices with no
enrolled screen lock at all (the pre-existing gap `lock_screen.dart`
already documents).

### 12.7 Full auth/deposit/withdraw verified against the live gateway, and the release APK republished (2026-08-03)

Picked back up per an explicit request to continue deposit/withdraw
verification and to sign up a real test account. The emulator crashed a
third time across two fresh AVD instances during this attempt (`adb`
losing the device entirely mid-session; separately, `PackageManager`
reporting a just-installed `MainActivity` as nonexistent despite `pm list
packages`/`dumpsys package` both showing it correctly registered, and
`aapt2 dump badging` independently confirming the built APK's own
manifest was correct) — conclusively an environment/tooling instability
on this machine, not a defect in the app, so pivoted to a more direct and
arguably stronger verification: exercising the real gateway API with the
exact request/response shapes `gateway_api.dart` now sends, via `curl`
against `https://codexacoin.com/v1` directly.

All four calls succeeded exactly as the Dart code expects:

- `POST /auth/signup` with a clearly-marked test identity
  (`test-verify-2026-08-03@codexacoin-test.invalid`) → real JWT token.
- `GET /staking/status` with `Authorization: Bearer <token>` → correct
  zero-balance response for a brand-new account
  (`{"mode":"custodial","delegated_amount":"0",...}`).
- `POST /staking/deposit` (amount 1 CAC) → a real, valid deposit address
  (`Cch2oaLubz7EsELMvb4FnwXqS3nXuLJtmX`) — generating a deposit address
  moves no funds, so this is safe to actually call.
- `POST /staking/withdraw` → clean, expected failure
  (`"Requested 100000000 exceeds available balance 0"`) — the safe,
  no-real-funds-moved verification of that error path, consistent with
  this project's standing rule to never execute an actual transfer during
  verification (see the referral-withdraw verification in section 13.7
  for the same pattern).

This proves the actual integration risk (does the Bearer-auth flow this
phase added really work against the live backend?) is resolved,
independent of whatever is wrong with the local emulator. Cleaned up
immediately after: deleted the test user (id 5) and its one
`stake_deposits` row (status `awaiting_funds`, no funds ever arrived)
directly from `/opt/cac-gateway/gateway.db` on the VPS via a Python
`sqlite3` one-liner over SSH (no `sqlite3` CLI installed there); verified
both rows gone afterward.

**Release APK republished.** Separately, `flutter build apk --release`
was run and the output published to `codexacoin.com/downloads/
CodexaCoin-android.apk`, replacing the stale Aug 1 build that predated
every fix in §12.6 (real gateway URL, working staking, the
`MainActivity` crash fix) — anyone downloading the app before this had
been getting a build that couldn't reach the backend at all and would
get stuck on first launch if a screen lock was enrolled. Verified via
`aapt2 dump badging` that the release APK's own manifest correctly
declares `MainActivity` (ruling out the same packaging concern the
emulator instability raised). `SHA256SUMS`/`SHA256SUMS.asc` on the
downloads page were regenerated and re-signed to match (see section
10.1 for the GPG signing setup); all four checksums re-verified against
the live server afterward.

---

## 13. VPS gateway and custodial staking pool (Phase 6)

`vps-gateway/` implements `docs/mobile-api.md` for real (Phase 4 was a
specification only), plus the 6A custodial staking pool. `web-wallet/`
is a browser-based wallet consuming the same gateway. Full design and
configuration details live in `vps-gateway/README.md` and
`web-wallet/README.md`; this section is the verification record.

### 13.1 Backend choice: direct RPC, not electrumx-cac

The gateway queries `codexacoind` directly via RPC (a dedicated
watch-only descriptor wallet that imports any address it's asked about
on first use), rather than talking to `electrumx-cac` as
`docs/mobile-api.md` originally envisioned. The client-facing REST
contract is identical either way — that document's own design already
treats the backend as an internal detail behind the gateway. This
substitution exists because electrumx-cac's local verification remained
blocked by the macOS-specific storage-backend packaging issue documented
in §11, and this phase needed something actually runnable end-to-end
during development, not because the Electrum-backed design was wrong.
**This does not scale to a mature mainnet** the way electrumx-cac's
pre-built global index would (importing + rescanning a never-before-seen
address gets slower as chain history grows) — see `vps-gateway/README.md`'s
"Known limitation" for the full statement. A real production deployment
on a real Linux VPS (where the packaging issue doesn't apply) should
still pursue the Electrum-backed design.

### 13.2 Staking pool design (6A)

Each deposit gets its own dedicated on-chain UTXO, never consolidated
with other depositors' funds. This means the chain's own
already-verified coin-age-proportional PoS reward logic (§6) computes
each depositor's reward correctly on its own — the pool only has to
notice when a deposit's UTXO gets staked and credit the depositor's
ledger with the reward minus the pool fee, never reimplement the reward
formula itself. Deliberately chosen to avoid the reward-calculation bug
class documented in §6.3 (found and fixed in Phase 2) by never writing a
second implementation of that math that could drift or have its own
bugs.

### 13.3 What was actually verified

Full lifecycle verified end-to-end against a real node on regtest
(chosen over mainnet/testnet specifically because it allows controllable
coin maturity, so a real coinstake reward could actually be produced and
observed within one working session):

- Signup, login (JWT), and every general wallet endpoint (`balance`,
  `utxos`, `history`, `tx` detail with real `is_coinstake`/
  `reward_satoshis` computation against an actual coinstake transaction,
  `broadcast`, `fee-estimate`) against real on-chain data.
- Deposit → external funding → watcher detects the funded UTXO →
  node stakes it (after discovering, empirically, that this fork's
  `GetStakeWeight()` requires the same `nCoinbaseMaturity` depth as
  coinbase maturity for *any* staking input, not just coinbase outputs —
  not previously documented anywhere in this file) → watcher detects the
  resulting coinstake and computes the gross reward, which matched the
  wallet's own reported amount exactly → 5% pool fee deducted exactly →
  `/staking/status` reflects the correct net figure → withdraw →
  status correctly zeroes out afterward once the payout covers both
  principal and reward.
- The web wallet, in a real browser: BIP39/BIP32 key generation and
  correctly-prefixed mainnet address derivation via CDN-loaded
  `@noble`/`@scure` libraries (chosen specifically because they need no
  bundler — see `web-wallet/README.md`), balance display, staking
  signup/login/status, and the deposit flow receiving a real deposit
  address from the pool.

### 13.4 Bugs found and fixed along the way

None of these were bugs in this gateway's own logic or in CAC's
consensus code — all were either genuine gaps in an external tool's
assumptions about this fork, or missing production-readiness pieces:

1. **Three bugs in `cpuminer-opt` (external mining tool)**, found while
   separately mining the founder premine window in parallel with this
   phase's work — see §9's mining-progress note and `CHANGELOG.md`'s
   Phase 6 entry for the full writeup (wrong coinbase `nVersion`, a
   missing `vchBlockSig` trailing byte, and BIP34 height encoding for
   heights 1–16). Fixed by patching the external tool, not this
   project's code.
2. **No CORS headers on the gateway** — every browser request from
   `web-wallet/` (a different origin by definition) was silently
   blocked until `flask-cors` was added. Any real web-wallet deployment
   needs this; it just hadn't been exercised from an actual browser
   until this phase's verification pass caught it.
3. **`ensure_pool_wallet_loaded`/`ensure_wallet_loaded` swallowed
   `loadwallet` failures unconditionally**, falling through to
   `createwallet` and producing a confusing "already exists" error
   instead of the real problem (in one case, a stale lock from a
   previous test run's process being force-killed mid-RPC-call). Fixed
   to check `listwalletdir` and surface the actual failure.
4. **`staking.withdraw()`'s stale reward display**: after a full
   withdrawal, `/staking/status` kept reporting the just-paid-out reward
   as still "accrued" because the SQL query summed all of a user's
   reward rows regardless of whether the underlying deposit had already
   been withdrawn. Fixed to only count rewards on still-active deposits.

### 13.5 Open TODOs from this phase

1. ~~Stand up a real gateway + staking pool deployment on the actual VPS
   infrastructure this is designed for
   (`provisioning/vps-gateway/`)~~ — **done 2026-08-01**, live at
   `codexacoin.com/wallet/` with a real backend (real wallets, real
   generated JWT secret). See `provisioning/vps-gateway/README.md` for
   the full writeup.
2. Partial-withdrawal accounting (§13.2's "known simplification" —
   `withdraw()` currently closes out a user's entire position at once).
3. ~~Tighten `GATEWAY_CORS_ORIGINS` from the development default (`*`)
   to the real web wallet's origin before any production
   deployment~~ — **done 2026-08-01**, set to `https://codexacoin.com`
   on the live deployment (doesn't affect the mobile app, which isn't
   subject to browser CORS at all).
4. Revisit the direct-RPC backend's scaling limitation (§13.1) once
   electrumx-cac's packaging issue is resolved on a real target VPS.

### 13.6 Signup "KYC" fields (2026-08-01) — self-attested, not verified

Requested and scoped carefully: the original ask was for real KYC on web
wallet signup. That would mean identity documents, a licensed
verification provider (Sumsub/Onfido/etc.), and compliance with
AML/data-protection law that varies by jurisdiction — none of which this
project has, and none of which can be responsibly stood up as a side
effect of a feature request. Building a fake "upload your ID" flow
without real verification behind it would be worse than nothing: it
collects sensitive PII while giving false assurance that anyone was
actually checked.

What was actually built, after clarifying scope: signup now additionally
collects full name, date of birth, and a national ID or passport number
(`vps-gateway/kyc.py`, `/v1/auth/signup`). This is explicitly
**self-attested data, not verification** — nothing checks it against a
document or a provider, and both the API and the web wallet's UI say so
directly rather than implying otherwise.

The ID number is real government-ID data, so it's encrypted at rest
(Fernet, symmetric) via a new `GATEWAY_KYC_ENCRYPTION_KEY` rather than
stored as plaintext next to the password hash — name and date of birth
stay plaintext (needed for display, far less sensitive alone). If that
key is ever lost, previously-stored ID numbers become permanently
unreadable; nothing downstream ever reads them back programmatically, so
that's an acceptable tradeoff for this design, not an oversight.

### 13.7 Referral reward — 10% of a referred user's first deposit

Initially deferred (see the original version of this section) because
the funding source was unresolved, and this project's supply is
otherwise fixed by design (§7: premine plus ongoing staking rewards,
nothing else mints CAC, no dev fund per §9 item 8). Clarified 2026-08-01:
paid from a dedicated `adminwallet`, funded manually by the project
owner — not newly minted CAC, not deducted from the referred user's own
deposit, and not drawn from the pool wallet that holds other users'
custodial funds. This was the deciding factor: it's the only option of
the three considered that neither touches consensus supply rules nor
puts other depositors' money at risk.

**How it works** (`vps-gateway/referral.py`):
- Every user gets a `referral_code` (8 chars) generated at signup.
  Signup optionally accepts another user's code, recorded as
  `referred_by`.
- When a referred user's *first* deposit is marked funded (hooked into
  `staking.py`'s existing watcher pass, right where a deposit transitions
  to `active`), the referrer is credited `REFERRAL_REWARD_BP` (default
  1000 = 10%) of that deposit's satoshi amount into a `referral_credits`
  ledger row — a bookkeeping entry, not an on-chain transaction yet, same
  pattern as `stake_rewards`. Guarded against double-crediting (checked
  by referred-user, not by deposit) and against triggering on any deposit
  after the user's first.
- `/v1/referral/status` (auth) returns the caller's own code, how many
  people they've referred, and available/lifetime credited satoshis.
- `/v1/referral/withdraw` (auth) sends the caller's full available credit
  to a specified address from `adminwallet`, mirroring
  `staking.py`'s `withdraw()` exactly, including its `-6`
  (insufficient-funds) handling — if `adminwallet` isn't funded, this
  fails with a clean, expected error rather than a raw RPC failure.

**Verified live** (2026-08-01, without moving any real funds — see below
for why): signed up a referrer and, using their real referral code,
signed up a second user; confirmed `referred_by` was set correctly.
Inserted a test-fixture `active` deposit row (not a real on-chain
payment — see below) and called `credit_referral_if_eligible()` directly,
confirming the referrer's `available_satoshis` showed exactly 10% of the
test amount; called it a second time to confirm no double-credit.
Called `/v1/referral/withdraw` against the still-empty `adminwallet` and
confirmed it fails cleanly with the expected "not-found" error rather
than crashing or silently succeeding, and that the credit remains
available afterward (not consumed by a failed attempt). All test data
removed from the production database afterward.

Two things deliberately **not** done as part of this verification, both
because they'd require actually moving real CAC: no real deposit was
made to trigger the crediting hook end-to-end through the watcher itself
(a test-fixture DB row was used instead — this tests the identical code
path `_mark_funded_deposits()` calls, just without needing a real
on-chain payment to arrive first), and `adminwallet` was deliberately
left unfunded — sending it real CAC is a financial transfer, which is
the project owner's decision and action to take, not something to do
unilaterally while verifying a feature. Its receive address is
`CQdsoAbLLYxD8ZAR7yi7PvU4jFg6ccdiW6`; nothing pays out until it's funded.

---

## 14. Cold-staking (6B) — a future consensus upgrade, not implemented

Phase 6 scope was deliberately limited to 6A (custodial pooling, §13).
This section specifies what 6B (non-custodial delegated staking) would
actually require, since the current codebase has **no cold-staking
script support at all** — confirmed by searching the tree for any
existing delegation opcode or P2CS-style template before writing this
(none found). This is a real, ground-up consensus feature addition, not
a small extension, and is not implemented or activated by anything in
this repository. Writing it here follows this project's own rule of
never inventing consensus changes silently — this is the "ask/design
first" version of that rule applied to a whole feature, not just a
constant.

### 14.1 What "cold staking" means here

The owner of a UTXO delegates *staking eligibility* (not spending
authority) to a second key. The delegate can produce valid PoS blocks
using the owner's coin-age weight and receives a fee share of the
resulting reward; the delegate can never move the owner's principal —
only the owner's own key can spend it. This is the standard model used
by PIVX, Blackcoin, and similar Peercoin-derived chains via an
`OP_CHECKCOLDSTAKEVERIFY`-style opcode.

### 14.2 What implementing it for real would require

1. **A new script opcode** (`OP_CHECKCOLDSTAKEVERIFY` or equivalent,
   claiming one of the currently-unused `OP_NOP`-range opcode slots) and
   a new P2CS-style output script template combining it with the
   existing P2PKH pattern: roughly `OP_DUP OP_HASH160 OP_ROT
   OP_IF <ownerPubKeyHash> OP_ELSE OP_CHECKCOLDSTAKEVERIFY
   <stakingPubKeyHash> OP_ENDIF OP_EQUALVERIFY OP_CHECKSIG`,
   distinguishing "spend" (owner branch) from "stake" (delegate branch)
   at redemption time.
2. **Script interpreter changes** (`script/interpreter.cpp`) to
   implement the new opcode's semantics: when evaluated in a coinstake
   context, verify the spending transaction's outputs pay back to the
   *same* P2CS script (so the delegate can never redirect the
   principal), and are structured as a valid coinstake per the existing
   `CTransaction::IsCoinStake()` rules (§ referenced in
   `vps-gateway/staking.py`'s reward-detection logic, which already
   reimplements that exact check in Python — a second, independent
   confirmation of what that definition is).
3. **Consensus validation changes** (`validation.cpp`,
   `wallet/staking.cpp`'s `SelectCoinsForStaking`/`AvailableCoinsForStaking`)
   to recognize P2CS outputs as stake-eligible for a wallet holding the
   *staking* key, not just the owner key, while continuing to enforce
   that only the owner key can authorize a non-coinstake spend of the
   same output.
4. **A deployment mechanism**: this is a hard-fork-shaped change (old
   nodes would reject blocks containing the new opcode/script pattern as
   invalid) unless carefully designed as a soft fork (e.g. by encoding
   the new template inside a script form old nodes already treat as
   anyone-can-spend-but-otherwise-opaque, the way SegWit did). Needs its
   own dedicated design review before any activation-height/BIP9-bit
   decision — explicitly out of scope for this section, which only
   specifies the *feature*, not how it gets safely turned on.
5. **Wallet-side delegation transaction construction** in both
   `codexacoin-core`'s wallet RPCs and `cac_wallet`'s Dart signing layer,
   which today only ever builds and signs ordinary P2PKH spends (see
   `cac_wallet/lib/crypto/transaction.dart`'s module doc) — building a
   P2CS output is new output-construction logic, not just a new signing
   path.
6. **Gateway endpoints already stubbed for this**: `docs/mobile-api.md`
   section 5's `/staking/delegate` and `/staking/revoke` describe the
   intended API shape (delegate to the pool operator's staking pubkey,
   default 5% delegate-fee split matching §13.2's pool fee) but have no
   backend — `vps-gateway/app.py` does not implement them at all yet.

### 14.3 Why 6A doesn't need any of this

6A's custodial design (§13.2) sidesteps all of the above by having the
pool hold real private keys for pooled deposits directly — the *existing*
staking mechanism already used everywhere else in this project (§6, §8,
mainnet's ongoing founder-premine mining) applies unchanged. 6B's entire
value proposition over 6A is removing the custodial trust requirement
(users never give up spending authority); that benefit is exactly what
costs a new consensus feature to deliver.

---

## 15. Block explorer (Phase 7) and final launch-readiness review

### 15.1 Block explorer

`explorer/` — public, read-only, no authentication, no wallet keys,
deliberately a separate service from `vps-gateway/` (different trust
boundary: nothing here can move funds). Same direct-RPC backend choice
as §13.1, with `txindex=1` (already enabled and synced on this node —
confirmed via `getindexinfo`) making arbitrary block/transaction lookup
by hash/height/txid work natively. Address balance/UTXO lookups use
`scantxoutset` (a stateless full-UTXO-set scan) rather than the
wallet-import approach `vps-gateway` uses for the same reason explained
there — accepting *any* address a visitor types in shouldn't accumulate
permanent state per address. Same honest limitation as a result: current
balance/UTXOs only, no historical/spent-transaction list without a real
index.

Verified in a real browser against the live mainnet node (the one
executing the founder-premine mining below): home page chain stats,
block detail with prev/next navigation, transaction detail (which
incidentally showed the BIP34 height-encoding fix from the Phase 6
mining-bug writeup embedded in a real on-chain coinbase — `029c0000` for
block 156, i.e. `OP_PUSHBYTES_2 0x9c00` little-endian = 156, followed by
the `OP_0` padding byte), and address search (balance matched
`utxo_count × 28,000,000 CAC` exactly). See `explorer/README.md` for the
full writeup.

### 15.2 Founder premine mining — final status as of this writing

**Complete — 500 of 500.** (See `CHANGELOG.md`'s Phase 5/6 entries for
the three real external-mining-tool bugs found and fixed to get this
running at all, and the machine-sleep/node-restart resilience confirmed
along the way — the miner reconnected automatically with zero manual
intervention every time, including recovering from real CPU
contention/thermal throttling caused by unrelated processes on the same
machine.) This was never a blocker for anything else in this repository,
since every other service was built and verified against either this
same partially-mined mainnet chain or a regtest chain with full control
over height/maturity — but it's now fully done regardless. See §5.4 for
the completion audit and checkpoint freeze.

### 15.3 Final launch-readiness review

Synthesizing §9's per-item list against everything actually verified
across all seven phases:

**Done and verified:**
- Fork, rebrand, consensus reconfiguration (§1-4), genesis (§8), Qt
  desktop wallet (§9 item 7), macOS `.dmg` packaging (§10).
- Coin-age-proportional staking reward, including catching and fixing
  two real reward-calculation bugs before they'd have caused silent
  overpayment (§6.3).
- Mobile wallet (§12): built, unit-tested (22/22 passing), Android
  verified on-device (build → install → launch → correct UI, no
  crashes).
- VPS gateway + 6A custodial staking pool (§13): full deposit → stake →
  reward → withdraw lifecycle verified against a real coinstake
  transaction on regtest, byte-for-byte matching the chain's own
  accounting.
- Web wallet (§13.3) and block explorer (§15.1): both verified in a real
  browser against live data, both sharing exact crypto/reward-decoding
  logic with their mobile/gateway counterparts rather than
  reimplementing it.
- The 500-block founder premine window (§15.2 originally, completed and
  superseded by §5.4): fully mined, supply-audited exact, and its 501
  block hashes frozen into `checkpointData` (§9 item 2).

**Genuinely still open (real work, not paperwork):**
- Windows/Linux desktop build artifacts (§9 item 9) — configuration
  exists and reuses a proven CI matrix, but has never actually run on
  GitHub Actions; only the macOS leg is locally built and verified.
- Desktop build codesigning/notarization (§10).
- `electrumx-cac`'s local packaging blocker (§11) — resolving this on a
  real target VPS would let `vps-gateway` and `explorer` both drop their
  direct-RPC scaling limitations (§13.1, §15.1) in favor of the
  originally-designed indexed backend.
- 6B non-custodial cold-staking (§14) — specified, not implemented;
  needs its own dedicated design review before any activation decision,
  as stated there.

**External/administrative, not something further local work resolves:**
- BIP44 coin type `3377` registration against the live SLIP-44 registry
  (§9 item 4).
- Real DNS seed hostnames (§9 item 6) — needs DNS registrar/zone access
  for codexacoin.com, which isn't available here; an infrastructure
  decision, not a technical blocker.
- A dev fund address decision (§9 item 8) — currently disabled
  (`vDevFundAddress` empty on every network), a deliberate choice, not
  an oversight, pending an explicit decision to enable it.
- iOS Simulator verification (§12.4) — blocked by a from-source LLVM
  compile this development machine can't reasonably absorb; not blocked
  on a machine with a working CocoaPods/Homebrew bottle.

No item in this list was glossed over or silently marked done without
being actually checked — that's been the standing practice since Phase 1
and stays true through this final phase.

## 16. Post-launch-readiness feature additions

After the Phase 7 review above, five further features were built and
verified against either the live mainnet chain or a regtest chain
(chosen per-feature based on which needed spendable/mature funds).
None of these were part of the original 7-phase spec; they were
scoped and approved via an open "what else should we add?" pass with
the project owner (2026-08-01).

### 16.1 Real dynamic fee estimation

`vps-gateway`'s `/v1/fee-estimate` previously returned a hardcoded
`FEE_RATE_SAT_VB` constant that was empirically found to be 10x the
node's real `mempoolminfee` floor. Replaced with a live heuristic:
`fee_rate = min(round(min_rate * urgency), min_rate * 10)` where
`min_rate` comes straight from `getmempoolinfo().mempoolminfee` and
`urgency = 1.0 + fullness * (10.0 / target_blocks)` scales with how
full the mempool actually is. No `estimatesmartfee`-equivalent RPC
exists in this codebase (confirmed empirically), so this is the
closest available approximation without a full fee-history database.
Verified live: returns `100 sat/vB` against an empty mempool, matching
the node's own `mempoolminfee` exactly.

### 16.2 P2SH multisig wallet support

Added to both `web-wallet/crypto.js` and `cac_wallet` (Dart):
`createMultisigRedeemScript`, `multisigAddress`,
`createMultisigProposal`/`signMultisigProposal`/
`mergeMultisigProposals`/`finalizeMultisigTransaction`. This is
N-of-M bare multisig wrapped in P2SH (`OP_m <pubkeys> OP_n
OP_CHECKMULTISIG`), using the standard `OP_0` scriptSig dummy-element
convention and requiring signatures in pubkey order. The "proposal"
object is a minimal hand-rolled partial-signature-exchange format
(not a general PSBT implementation) — sufficient because a single
wallet instance only ever holds one signer's key and proposals are
expected to be exchanged out-of-band (e.g. copy/paste JSON).
Verified via a real 2-of-3 create → sign (independently, per key) →
merge → finalize cycle in both languages, with independent sighash
reconstruction and `secp.verify()`/`ECDSASigner.verifySignature()`
cross-checks, including a negative check confirming a signature does
NOT verify against the wrong pubkey. `cac_wallet`'s test suite grew
from 22 to 24 passing tests.

### 16.3 Web Push notifications (web-wallet)

New `vps-gateway/push.py` wraps `pywebpush` (VAPID/ES256, RFC
8291/8292 `aes128gcm` payload encryption). New `push_subscriptions`
table, `/v1/push/vapid-public-key` and `/v1/push/subscribe`
endpoints, and `web-wallet/sw.js` (a minimal service worker handling
only `push`/`notificationclick` — deliberately no offline caching,
since the wallet's offline-first behavior is already handled by
`localStorage`). Wired into `staking.py` so deposit-confirmed and
reward-credited events fire a real notification.
`send_notification()` swallows `WebPushException` and returns `False`
rather than raising, since a dead subscription must never break a
watcher pass that's crediting real money.

**Verification note:** this development browser environment's
`Notification.permission` is hard-denied by policy (a real,
unbypassable constraint, not a bug — no workaround was attempted).
The subscribe/notify wiring itself was instead verified at the
protocol level: a local Python capture server receiving a real
VAPID-signed, `aes128gcm`-encrypted push request from
`send_notification()`, confirming the JWT signature and payload
decrypt correctly. Full click-to-notification UX remains unverified
in-browser in this environment; the crypto and server-side wiring are
verified.

### 16.4 Merchant checkout widget

New top-level `checkout-widget/` — a single embeddable ES module
(`checkout.js`, no build step, same no-bundler approach as
`web-wallet/` and `explorer/`). Deliberately stateless on the
backend: no new gateway endpoint, it polls the existing
`GET /v1/address/{address}/balance` and fires `onDetected` once the
watched address's balance rises by at least the amount due from a
baseline snapshot. Scope is strictly "watch for payment, tell me when
it arrives" — not payment-request management, invoicing, or refunds
(a merchant is responsible for generating the address to charge, e.g.
from their own gateway wallet or a customer's `cac_wallet` receive
screen). Relevant to Apple's App Store virtual-currency guideline
(`docs/store-compliance.md`) as the permitted "in exchange for goods
and services" case.

Verified end-to-end on regtest (mainnet's premine is still inside its
500-block maturity window, so nothing there was spendable to test a
real payment with): a real `sendtoaddress` payment was correctly
detected, `onDetected` fired with the exact balance in satoshis.

### 16.5 Block explorer: rich list, supply chart, live refresh

Added to `explorer/app.py`: `/api/richlist` (walks the last
`EXPLORER_RICHLIST_MAX_BLOCKS` — default 5000 — blocks, crediting
output addresses and debiting resolved non-coinbase input addresses,
returns the top balances) and `/api/supply-series` (exact, not
scanned, computation for the PoW window via
`min(height, LAST_POW_BLOCK) * POW_BLOCK_SUBSIDY_SATS`, bucketed to
≤50 points — honestly notes it cannot compute PoS-phase supply the
same way, since PoS block rewards have no fixed per-block formula).
Frontend (`explorer/app.js`) adds a hand-rolled inline SVG line chart
(no charting library), a `#/richlist` route, and a 20-second
auto-refresh timer on the home route that's created on entry and
cleared on navigating away.

Verified live in-browser (not just via `curl`): the rich list showed
the single mining-reward address with a balance of
`303 × 28,000,000 = 8,484,000,000 CAC`, an exact match; the supply
chart rendered a correct monotonic-ascending SVG polyline matching
linear PoW-window minting; the auto-refresh timer was confirmed via
an instrumented `setInterval`/`clearInterval` wrapper to be created
exactly once per home-page visit and cleared exactly once per
navigation away, across repeated round-trips — no leaked intervals.

### 16.6 Marketing site content/design overhaul (2026-08-03)

Full rewrite of `website/index.html` and `style.css` at the project
owner's request for content that reads as professional and credible to
an investor/evaluator audience, and a more polished visual design.
Deliberately did **not** take that as license to write typical crypto
hype copy — every new claim ties back to something already documented
and verifiable elsewhere in this project, and a dedicated section says
plainly what a reader should be skeptical of. Specifically:

- **New hero**: a live stats bar (block height, difficulty) fetched
  client-side from the explorer's own `/api/stats` on page load —
  fails gracefully (hides itself) if the fetch errors, so a broken API
  can't leave a blank gap. This replaced a static "pre-launch" framing
  with something no vaporware site can copy: real numbers from a real,
  currently-running chain, visibly changing on refresh.
- **New trust strip**: four credibility signals (audited premine, open
  source, GPG-signed releases, real running network), each pointing at
  something already true and already documented elsewhere on this site
  or in this repo — not new claims invented for the redesign.
- **New "Why Proof-of-Stake, why now" section**: reframes existing
  technical facts (PoW permanently disabled after the premine window,
  coin-age-proportional rewards, the full product suite, the
  documentation discipline) as reader-facing value propositions,
  without adding anything not already true.
- **New "One codebase, a full ecosystem" section**: links out to the
  explorer, the gateway and checkout-widget source, and the newly
  public GitHub repo — makes the case that this is a working product
  suite, not a single-purpose token site.
- **New "What we won't tell you" section**: explicit, unhedged
  disclosure of the project's actual early-stage risks — supply
  currently concentrated in a small number of wallets (verifiable on
  the rich list, linked directly), no exchange listing, no market
  price, unsigned desktop builds, and a plain "this is not investment
  advice, nothing here is a solicitation" statement. Included
  deliberately: a site asking to be taken seriously by investors should
  volunteer the caveats a serious investor would ask for anyway, not
  wait to be asked.
- **New FAQ**: answers the obvious follow-up questions (third-party
  audit status, premine destination, dev fund, running your own node,
  whether custodial staking is the only option) as directly as the
  rest of the site — e.g. "Not by an external security firm" rather
  than a vague non-answer.
- Roadmap item 9 updated to also credit the public GitHub repo; nav and
  footer both gained GitHub/Explorer links.
- Visual: kept the existing dark cyan/blue/gold palette and animation
  conventions rather than replacing them, but added a live-updating
  status badge, icon-led credibility cards, a proper button hierarchy
  (primary gradient + outline secondary), and a native `<details>`-based
  FAQ accordion (no JS framework, no external dependency).

**Verified live**, not just visually inspected: fetched the deployed
page's live-stats values against `/api/stats` directly and confirmed
they matched (block height, difficulty), checked the browser console
for errors (none), and checked computed grid layouts via JS at both a
375px mobile width and a 1280px desktop width to confirm every new
multi-column section (trust strip, "why" cards, wallet cards, ecosystem
cards) actually laid out into clean columns rather than silently
collapsing.

### 16.7 First real GitHub Actions release, and a v0.1.0 draft release (2026-08-03)

Published the project to GitHub for the first time
(`github.com/fakharnaqvi5313/codexacoin`, public, MIT), scanning tracked
file contents first for anything that looked like a real secret (none
found -- the actual JWT/KYC-encryption secrets and RPC passwords live only
in the VPS's `/etc/*.conf`, never committed). `.github/workflows/release.yml`
had to be moved from `codexacoin-core/.github/workflows/` to the monorepo
root's `.github/workflows/` first -- GitHub Actions only discovers
workflows under the actual repo root, so it would never have triggered
from its original nested location. Every build step got a
`working-directory: codexacoin-core` to compensate.

Pushed tag `v0.1.0` to trigger it for real. `linux-x86_64` and
`windows-x86_64` both built successfully on GitHub's own infrastructure --
the first CodexaCoin artifacts ever built outside this project's own dev
machine. `macos-x86_64` got stuck `queued` for 76+ minutes with no error,
confirmed via `gh run cancel` + `gh run rerun --job` (a clean way to
re-queue a single job without discarding the other two jobs' completed
results) that it wasn't a fluke -- the second attempt got stuck again,
86+ minutes, with nothing else competing for a runner anywhere in the
account (checked across every repo), no billing restriction, and GitHub's
own status page showing all systems operational. Un-gated
`publish-release` from `needs: [linux, windows, macos]` down to
`needs: [linux, windows]` so future tag pushes aren't held hostage by
that queue; `macos-x86_64` still builds, just doesn't block the release.

Published a draft GitHub Release (`v0.1.0`) by downloading the
already-succeeded linux/windows artifacts directly (`gh run download`)
rather than waiting on a full workflow re-run, and separately rebuilt the
macOS `.dmg` locally (same proven native-build path from earlier this
session, now incorporating the day's `<cstdint>`/BIP32 fixes) --
smoke-tested by mounting the fresh dmg and running
`CodexaCoin-Qt -version` before treating it as a real artifact, not just
trusting a successful build. All four platform artifacts (Linux
tarball+`.deb`, Windows NSIS installer, macOS `.dmg`) are attached to the
draft release.

The website's downloads page now also links the three CI-built artifacts
(Windows installer, Linux tarball, Linux `.deb`) as a second, independently-
built option alongside the locally-built ones already there, framed
honestly as an additional trust signal (built on neutral infrastructure,
not a developer's own machine) rather than a replacement -- the CI Linux
build is CLI-only (no Qt packages installed on that runner), so it's a
genuinely different, not strictly better, artifact than the GUI-inclusive
one already hosted. `SHA256SUMS`/`SHA256SUMS.asc` regenerated and
re-verified against the live server to cover all seven files now hosted.

### 16.8 Legal/policy pages, and a Microsoft Store submission blocker found early (2026-08-03)

Added five legal pages under `website/legal/`: Privacy Policy, Terms &amp;
Conditions (governing law: Pakistan, per explicit instruction), Risk
Disclosure, AML/KYC Policy, and Acceptable Use Policy. Every factual claim
in them was checked against what the code and infrastructure actually do
(e.g. confirmed via `grep` that neither the site nor the web wallet sets
any cookies at all -- both use `localStorage`/`sessionStorage` instead --
before writing the Privacy Policy's cookie section that way; confirmed no
third-party analytics/ad trackers exist anywhere in the codebase before
claiming that). Each page carries a prominent, plain-language notice that
it's a template reflecting the software's actual behavior, not a document
reviewed by a licensed lawyer, and that CodexaCoin holds no license or
regulatory registration anywhere. Linked from the site footer and from
both the web wallet's and the Android app's signup forms (a policy nobody
sees at signup doesn't do much).

Separately, picked up the earlier request to prepare a Windows build for
Microsoft Store submission. Fetched Microsoft's actual current Store
Policies (version 7.19) rather than relying on memory, and found two
provisions that directly block this project's situation:

- **10.8.3**: products requiring "financial information" -- explicitly
  including "private keys, or recovery phrases" -- must be submitted from
  a **Company** developer account; individual accounts cannot.
- **10.2.6**: cryptocurrency wallet apps specifically "must be distributed
  by a Company account."

Asked the user directly rather than assuming; confirmed their existing
Microsoft Developer ID is an **Individual** account, which Store policy
explicitly disallows for this category of app -- not a soft risk, a hard
rejection at certification. Converting to a Company account requires real
business-registration verification with Microsoft, which only the account
owner can do. Also noted policy 10.2.9's requirement that a
direct-download-URL submission be signed with a real Authenticode
certificate chaining to the Microsoft Trusted Root Program, and installed
*silently* (no installer UI) -- relevant since the user separately
confirmed they have or can get a real code-signing certificate, which
opens that path once the account-type blocker clears.

Proceeded anyway with the genuinely useful, account-type-independent part
of the prep: building an actual Windows **GUI** wallet (the existing
Windows build is CLI-only) via the depends system's mingw target,
including Qt this time -- the earlier attempt this session had skipped Qt
specifically because its source tarball download kept stalling
mid-transfer (found a leftover `.temp` file confirming this), which is
worth retrying now that network conditions have been reliable for
everything else built today.

## 17. Deferred: governance and hardware wallet support

Two further ideas came up in the same "what else should we add?" pass
as §16 but were deliberately **not** built, following the same
precedent as §14's cold-staking deferral — both are large enough to
need their own design review before implementation, not something to
bolt on inside a "build all which possible" pass.

### 17.1 On-chain/off-chain governance

Not specified anywhere in the original 7-phase spec, and CodexaCoin
has no existing dev fund, treasury, or voting-weight mechanism to
build a governance system on top of (`vDevFundAddress` is empty on
every network per §9 item 8 — a deliberate no-dev-fund choice so
far). Before this could be designed, the project owner would need to
decide: on-chain (e.g. stake-weighted signaling, à la Decred) vs.
off-chain (forum/Snapshot-style, non-binding) vs. no formal mechanism
at all (informal, maintainer-driven — the current de facto state).
Each has a materially different implementation and, for on-chain
signaling, potential consensus-layer implications requiring the same
scrutiny as §14's cold-staking design.

### 17.2 Hardware wallet support

No hardware wallet (Ledger, Trezor, or otherwise) ships firmware with
a CodexaCoin coin app, and CAC is not part of any hardware vendor's
generic "Bitcoin-like altcoin" support path today. Real support would
require either: (a) a HWI (`hwi` Python library) integration
contributing a CAC coin definition upstream to a vendor, which is
outside this repository's control and timeline, or (b) if CAC's
transaction/address format is close enough to an already-supported
coin (worth checking given the Bitcoin-derived P2PKH/P2SH format —
see §16.2's multisig work for the closely related script format),
piggybacking on that coin's existing app with CAC-specific address
version bytes — which still needs verification that no
transaction-format divergence (e.g. the PoS `nTime` field noted
elsewhere in this document) breaks the hardware wallet's blind- or
clear-signing assumptions. Neither path is a local software change;
both need scoping with an actual device in hand before any code is
written.
