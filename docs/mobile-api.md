# CodexaCoin Mobile API Gateway Specification

Phase 4 deliverable. This is a **specification for a gateway service that
does not exist yet** — the actual implementation is Phase 5/6 work (built
alongside the mobile apps and the staking service, since the staking
endpoints below have no backend until Phase 6). What exists today
(Phase 4) is the thing this gateway will sit in front of:
`electrumx-cac` (see `../electrumx-cac/` and
`../provisioning/electrumx/`).

## Why a REST gateway in front of Electrum, not raw Electrum protocol

Real Electrum-based desktop wallets talk the Electrum JSON-RPC-over-TCP/SSL
protocol directly. Mobile apps *could* do the same, but:

1. The Electrum protocol is script-hash-indexed (SHA256 of the output
   script, reversed) — every client needs correct script→scripthash
   derivation for every address type (P2PKH, P2SH, bech32) before it can
   ask "what's my balance". A REST layer that accepts addresses directly
   removes an entire class of mobile-client bugs.
2. Electrum protocol connections are long-lived, stateful (subscriptions,
   notifications) — fine for a desktop app that stays running, awkward for
   a mobile app that gets backgrounded/killed by the OS constantly. A
   stateless REST API is a much better fit for mobile's actual lifecycle.
3. The staking-service endpoints (§5) have **no Electrum equivalent at
   all** — they need a purpose-built backend regardless (Phase 6A/6B).

So: one gateway, REST/JSON, stateless, backed internally by one or more
`electrumx-cac` instances (wallet data: §2-4) plus the staking service
once it exists (§5). Mobile apps talk to the gateway; the gateway talks to
Electrum servers and the staking backend. Mobile apps never connect to
Electrum servers directly, and never see the staking backend's internals.

## Conventions

- Base URL: `https://api.codexacoin.example/v1` (placeholder — see
  PARAMETERS.md's TODO list for real infrastructure; format
  `https://<gateway-host>/v1`).
- All amounts are strings in satoshis (`CAmount`, 8 decimals — see
  PARAMETERS.md §2), never floats, to avoid client-side precision bugs.
  Format as CAC client-side by dividing by `100000000`.
- All requests/responses are JSON. `Content-Type: application/json`.
- Errors follow a consistent shape (see §6).
- No authentication for read endpoints (§2-4 are public blockchain data,
  same trust model as a public Electrum server). §5 (staking) requires
  auth — see that section.
- Rate limiting: per-IP, details TBD when the gateway is actually built;
  mirror the faucet's pattern (`../faucet/app.py`) of Flask-Limiter-style
  fixed-window limits, tuned much looser than the faucet's since this is
  wallet-critical infrastructure, not a giveaway.

## 1. Health / network info

### `GET /v1/network/status`

```json
{
  "network": "mainnet",
  "chain_height": 812345,
  "best_block_hash": "000000...",
  "electrum_servers_healthy": 2,
  "electrum_servers_total": 2
}
```

Gateway-internal: queries `server.version` + `blockchain.headers.subscribe`
against each configured `electrumx-cac` backend, returns the aggregate.

## 2. Balance

### `GET /v1/address/{address}/balance`

```json
{
  "address": "CRD6aiuoa3sv2ToqcszF3GmjRW8FDdBcHU",
  "confirmed": "1400003034000000",
  "unconfirmed": "0"
}
```

Gateway-internal: derive scripthash from `address`, call
`blockchain.scripthash.get_balance`.

**Note on "stake" balance**: coin-age rewards accrue directly into the
staker's own spendable balance the moment their coinstake confirms (see
PARAMETERS.md §6) — there's no separate "staking balance" bucket at the
protocol level the way `overviewpage.ui`'s desktop-wallet "Stake" row
shows (that's specifically the *immature*, still-maturing coinstake output
for wallets that are themselves actively staking, not something mobile
needs since mobile never stakes on-device — see
`docs/store-compliance.md`, Phase 5).

## 3. UTXOs

### `GET /v1/address/{address}/utxos`

```json
{
  "address": "CRD6aiuoa3sv2ToqcszF3GmjRW8FDdBcHU",
  "utxos": [
    {
      "txid": "abcd...",
      "vout": 0,
      "value": "2800000000000000",
      "height": 501,
      "confirmations": 12
    }
  ]
}
```

Gateway-internal: `blockchain.scripthash.listunspent`, enriched with
`confirmations` (computed from `height` and current chain tip, since the
raw Electrum response only gives height).

## 4. Transaction history, details, broadcast, fee estimate

### `GET /v1/address/{address}/history?limit=50&before_height=<h>`

```json
{
  "address": "CRD6aiuoa3sv2ToqcszF3GmjRW8FDdBcHU",
  "transactions": [
    {"txid": "abcd...", "height": 501, "fee": null}
  ],
  "has_more": false
}
```

Gateway-internal: `blockchain.scripthash.get_history` (+ pending mempool
entries via `blockchain.scripthash.get_mempool`), paginated
gateway-side since Electrum returns the full history in one call.

### `GET /v1/tx/{txid}`

Full transaction detail (decoded, not just raw hex) — inputs, outputs,
addresses, value, confirmations, and (for coinstake transactions
specifically) the coin-age reward amount, computed gateway-side the same
way `feature_coinage_reward.py` does for testing: reward = (sum of
coinstake outputs) − (sum of coinstake inputs).

```json
{
  "txid": "abcd...",
  "height": 501,
  "confirmations": 12,
  "is_coinstake": true,
  "reward_satoshis": "6069027198",
  "vin": [...],
  "vout": [...]
}
```

Gateway-internal: `blockchain.transaction.get` (verbose), plus the
reward-delta computation above for coinstake txs.

### `POST /v1/tx/broadcast`

Request:
```json
{"raw_tx_hex": "0200000001..."}
```

Response (success):
```json
{"txid": "abcd..."}
```

Response (rejected):
```json
{"error": {"code": "tx-rejected", "message": "bad-txns-inputs-missingorspent"}}
```

Gateway-internal: `blockchain.transaction.broadcast`. The gateway does
**not** sign anything — signing happens entirely client-side on the
mobile device (see `docs/store-compliance.md`, Phase 5: keys never leave
the device). This endpoint only relays an already-signed transaction.

### `GET /v1/fee-estimate?target_blocks=6`

```json
{"target_blocks": 6, "fee_rate_sat_per_vbyte": "1000"}
```

Gateway-internal: `blockchain.estimatefee`. Note `BlackcoinDaemon` (which
`CodexaCoin`'s `electrumx-cac` coin definition reuses as-is — see
`electrumx-cac/src/electrumx/lib/coins.py`) returns a **fixed**
`ESTIMATE_FEE` rather than a real dynamic estimate, because this
Bitcoin-Core-derived codebase doesn't implement the `estimatesmartfee`-style
RPCs Blackcoin/CAC lack. Document this plainly in the mobile app's fee UI
rather than presenting it as a real-time estimate — it's a fixed default,
not measured from the actual current mempool.

## 5. Staking service (Phase 6 — not implemented yet)

These endpoints don't exist behind any real backend today; specified now
so mobile app development (Phase 5) can build against a stable contract
and swap in the real thing once Phase 6 ships. All require
authentication — a bearer token issued at account creation (mechanism TBD
in Phase 6, likely tied to the custodial pool's own user accounts for 6A,
and just a signature-based proof-of-address-ownership for the
non-custodial 6B flow, which never needs a traditional account at all).

### `GET /v1/staking/status` (auth required)

```json
{
  "mode": "custodial",
  "delegated_amount": "500000000000000",
  "accrued_rewards": "5700000000",
  "effective_monthly_rate_bp": 1368,
  "pool_fee_bp": 500,
  "can_withdraw": true
}
```

`mode` is `"custodial"` (6A) or `"delegated"` (6B, once cold-staking
ships) — see PARAMETERS.md's Phase 6 design. `effective_monthly_rate_bp`
echoes `nStakeRewardAnnualBP / 12` (basis points) so the mobile UI never
hardcodes the rate and stays correct if the consensus parameter is ever
tuned (see PARAMETERS.md §7.3 — this is the documented governance lever).

### `POST /v1/staking/deposit` (auth required, 6A only)

Request: `{"amount": "500000000000000"}` — returns a deposit address to
send funds to (custodial pool address). Mobile app builds and broadcasts
the funding transaction itself via §4's broadcast endpoint, same as any
other send.

### `POST /v1/staking/withdraw` (auth required, 6A only)

Request: `{"amount": "500000000000000", "to_address": "C..."}` — the
*user's own* address, per PARAMETERS.md's custodial design (withdrawals
go back to an address the user's own device controls the key for, never
anywhere else).

### `POST /v1/staking/delegate` (auth required, 6B only, once cold-staking ships)

Request: `{"owner_address": "C...", "amount": "500000000000000"}` —
initiates the on-chain P2CS delegation (PARAMETERS.md Phase 6B). The
mobile app signs the delegation transaction client-side; this endpoint
just returns the delegate (VPS operator) public key to delegate to and
the current default delegate-fee split, matching PARAMETERS.md §A.4's 5%
default.

### `POST /v1/staking/revoke` (auth required, 6B only)

Request: `{"owner_address": "C..."}` — same client-side-signing pattern
as delegate.

## 6. Error format

All non-2xx responses:

```json
{
  "error": {
    "code": "invalid-address",
    "message": "Human-readable description",
    "details": {}
  }
}
```

Standard `code` values: `invalid-address`, `not-found`, `tx-rejected`,
`electrum-backend-unavailable`, `rate-limited`, `unauthorized` (§5 only).

## 7. What this spec deliberately does not cover yet

- Push notifications for incoming transactions (Phase 5 mobile-app
  concern — likely built on Electrum's `scripthash.subscribe`
  notifications, fanned out via the gateway to APNs/FCM, but not
  specified here since it needs the actual mobile app architecture
  decided first).
- Exact auth mechanism for §5 (deliberately TBD — see above).
- Multi-backend failover/load-balancing behavior when the gateway has more
  than one `electrumx-cac` instance behind it (operational detail for
  whoever deploys the gateway, not a client-facing contract change).
