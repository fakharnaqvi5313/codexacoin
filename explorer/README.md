# explorer

Phase 7 deliverable. A public, read-only block explorer — separate
service from `../vps-gateway/` (which holds real wallet/staking-pool
private keys). No authentication, no wallet keys, nothing here can move
funds.

## Backend

Direct `codexacoind` RPC (`txindex=1`, already enabled on this node —
confirmed via `getindexinfo` — makes arbitrary block/transaction lookup
by hash/txid work natively, no separate indexer needed for those).
Address balance/UTXO lookups use `scantxoutset`, a stateless full-UTXO-set
scan, rather than importing addresses into a wallet the way
`vps-gateway/app.py` does — appropriate here specifically because the
explorer has to accept *any* address a visitor types in without
accumulating permanent wallet state for each one.

**Known limitation**, stated in the API response itself, not just here:
`scantxoutset` only sees the *current* UTXO set. Address pages show
accurate current balance/UTXOs but not historical (already-spent)
transactions — that needs a real index (`electrumx-cac`, still blocked
locally by the packaging issue in `PARAMETERS.md` section 11). Block and
transaction lookups by hash/height/txid are unaffected by this — those
work fully and precisely via `txindex`.

## Frontend

Static, bundler-free (same approach as `../web-wallet/`), hash-routed
(`#/block/<height-or-hash>`, `#/tx/<txid>`, `#/address/<address>`).

## Running locally

```bash
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
export CAC_RPC_USER=... CAC_RPC_PASSWORD=...
python3 app.py              # backend, port 8081
python3 -m http.server 8091 # frontend, separately -- set localStorage
                             # "cac_explorer_api" if not http://127.0.0.1:8081
```

## Verification (Phase 7)

Tested in a real browser against the live mainnet node (the one
executing the founder-premine mining described in `PARAMETERS.md`
section 5): home page stats (minted-so-far figure matched
`height × 28,000,000 CAC` exactly), block detail with prev/next
navigation, transaction detail (correctly showed the BIP34 height
encoding fix from `CHANGELOG.md`'s Phase 6 mining-bugs entry embedded in
a real on-chain coinbase), and address lookup (balance matched
`utxo_count × 28,000,000 CAC` exactly for the mining reward address). No
coinstake transaction existed yet to verify the reward-decoding path
against on this specific chain (still inside the PoW premine window at
verification time) — that logic is identical to
`vps-gateway/app.py`'s, already verified against a real coinstake on
regtest in Phase 6.
