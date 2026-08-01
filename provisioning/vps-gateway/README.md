# vps-gateway + web-wallet deployment (real, 2026-08-01)

The web wallet is live at
[codexacoin.com/wallet](https://codexacoin.com/wallet/), backed by a real
`vps-gateway` instance on the same VPS as
[../explorer/](../explorer/README.md) and [../website/](../website/README.md).

## What's different from the explorer's node

The explorer's `codexacoind` was deliberately built with
`--disable-wallet` (see `../explorer/README.md`) — read-only, no keys,
lowest possible trust surface. The gateway needs the opposite: real
wallets holding real keys for the custodial staking pool (see
`../../PARAMETERS.md` section 13 for the design). So the same node was
rebuilt with wallet support enabled (`libsqlite3-dev` installed,
`--disable-wallet` dropped from `./configure`) and now serves both
services from the one binary — simplest option on a small VPS, and safe
specifically because the explorer never loads any wallet regardless of
whether the binary supports one.

Two wallets were created directly via RPC (`createwallet`, descriptor/SQLite
form — legacy BDB wallet creation is deprecated in this codebase and
was rejected outright when first tried with the wrong positional arg):

- `gateway` — watch-only, `disable_private_keys=true`, used for arbitrary
  address balance/UTXO lookups (matches `../../vps-gateway/app.py`'s
  `GATEWAY_WATCH_WALLET`).
- `stakingpool` — holds real keys, used for the 6A custodial pool
  (matches `GATEWAY_POOL_WALLET`).

Both unencrypted (no passphrase) — required so the gateway can sign
transactions programmatically without a `walletpassphrase` call before
every operation, matching how the pool wallet already worked in earlier
local verification. This is an inherent tradeoff of the custodial design
already documented in `PARAMETERS.md` section 13, not something new
introduced by this deployment.

`/etc/cac-gateway.conf` holds a real, freshly-generated
`GATEWAY_JWT_SECRET` (`openssl rand -hex 32`) — not the dev-only default
`app.py` falls back to.

## A real code fix needed for production

`web-wallet/app.js`'s `GATEWAY_URLS` defaulted to
`http://127.0.0.1:8080` — fine for local dev (wallet and gateway both on
localhost during testing) but wrong once deployed, since the wallet's
static files are served from `codexacoin.com` while that hardcoded URL
would still point at the visitor's own machine. Changed the default to
an empty string, matching `explorer/app.js` and
`checkout-widget/checkout.js`'s already-established "same-origin by
default, override via localStorage for local dev" convention. nginx
proxies `/v1/` to the gateway at the site root (same pattern as the
explorer's `/api/`), so this needed no other changes.

## Verified live

Created a real wallet in the browser at `codexacoin.com/wallet/`: real
BIP39 mnemonic generated client-side, the derived receive address
(`CV7s6hL78Mv76j9nqQYsyBox7sUBhmDihU`) confirmed valid via the node's own
`validateaddress`, and its balance query confirmed round-tripping for
real through nginx → gateway → node RPC (checked via the browser's
network log, not just that the page rendered). Also exercised
`/v1/auth/signup` directly against the production JWT secret to confirm
the auth/database path works, then deleted the test account from
`gateway.db` afterward.
