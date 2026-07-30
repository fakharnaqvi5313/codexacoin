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

**Maturity-drag calibration (§A.3 of spec):** the regtest calibration test
(Phase 1 deliverable, not yet run) will measure the *realized* monthly rate
after the 500-block (≈8.9h) coinstake lockup drag and confirm whether
`STAKE_REWARD_ANNUAL_BP = 1368` needs to be bumped (spec suggests ~1420) to make
realized ≈ 1368 bp at typical pool UTXO sizing. **Final calibrated value will be
recorded here once that test exists and has run — currently still the
uncalibrated default.**

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
| Timestamp phrase (mainnet) | `"CNBC 28/Jul/2026 Dow drops 1,100 points for worst day since April 2025 on fear the Fed is falling behind on inflation"` |
| Source | [CNBC, published 2026-07-28](https://www.cnbc.com/2026/07/28/stock-market-today-live-updates.html) — verifiable, dated, independent financial-news headline, mirroring Bitcoin's own genesis-message convention (news source + date + headline). |
| nTime / nNonce / nBits | **TODO** — to be generated by the `-gengenesis` tool (Phase 1 deliverable, not yet built) once chainparams edits land; must be mined fresh for CAC's new `powLimit`/`posLimit` and address prefixes. |
| Genesis reward | `0` (matches Blackcoin convention — genesis coinbase is unspendable regardless, see §5) |

---

## 9. Open TODOs before any public launch

1. Generate the actual genesis block (nTime/nNonce/hash) once chainparams code
   changes are complete.
2. Mine the 500-block founder premine window privately, verify total = exactly
   14,000,000,000 CAC via the supply-audit script, then freeze those 500 block
   hashes into `checkpointData`.
3. Run the coin-age reward regtest calibration test and record the
   final-calibrated `STAKE_REWARD_ANNUAL_BP` here (§6).
4. Register (or at minimum re-verify non-collision of) BIP44 coin type `3377`
   against the live SLIP-44 registry.
5. Choose dedicated BIP32 xpub/xprv version bytes instead of reusing Bitcoin's
   (not consensus-critical, cosmetic/compatibility only).
6. Stand up real DNS seed hostnames (`seed1.codexacoin.example` etc. are
   placeholders — see chainparams TODOs once written).
