# web-wallet

Phase 6 deliverable. A static, browser-based CodexaCoin wallet — no
build step, no bundler, no Node.js toolchain. Talks to `../vps-gateway/`
using the exact same REST contract (`../docs/mobile-api.md`) as the
mobile app (`../cac_wallet/`).

## Why no bundler

`crypto.js` hand-implements address encoding and transaction signing
(mirroring `cac_wallet/lib/crypto/*.dart` exactly, same algorithms, same
byte layouts — a recovery phrase created on one restores identically on
the other), built on the `@noble`/`@scure` crypto libraries loaded
directly as ES modules from jsDelivr's `+esm` CDN endpoint. Those
libraries are specifically designed for this — dependency-free,
browser-native `Uint8Array` APIs, no `Buffer` polyfill needed — which is
why they work reliably via plain `<script type="module">` imports
without a bundler, unlike most general-purpose Bitcoin JS libraries.

**This means the page needs network access to jsDelivr to load.** Fine
for a real deployment (completely normal to depend on a CDN); if fully
offline operation is ever needed, vendor those four packages locally and
change the four `https://cdn.jsdelivr.net/...` import specifiers in
`crypto.js` to local paths — nothing else changes.

## Security note (also shown in-app, on the onboarding screen)

Unlike the mobile app — which stores the recovery phrase in the OS
Keychain/Keystore (see `docs/store-compliance.md`) — this web wallet
keeps it in the browser's `localStorage`. That's meaningfully weaker:
anyone with access to the browser profile, or a malicious extension, can
read it. This is stated plainly in the app itself, not just here. Best
suited for testnet/small amounts or as a reference implementation; the
mobile app is the safer choice for real funds.

## Running locally

Needs to be served over HTTP (ES module imports fail over `file://`):

```bash
python3 -m http.server 8090
```

Then open `http://127.0.0.1:8090`, with `../vps-gateway/` running and
reachable (CORS must be enabled there — see its `GATEWAY_CORS_ORIGINS`
env var — for the browser to be allowed to call it from a different
origin).

## Verification (Phase 6)

Tested in a real browser (not just read for correctness): wallet
creation (real BIP39 mnemonic + BIP32 derivation via the CDN-loaded
libraries, producing a real, correctly-prefixed mainnet address),
balance display against the live gateway, staking pool signup/login/
status display, and the full staking deposit flow (received a real
deposit address from the pool). Found and fixed two real bugs in the
process: the gateway had no CORS headers at all (blocked every
cross-origin browser request until added — see `vps-gateway/app.py`),
and a stale error message that wasn't cleared on a subsequent successful
action. See `CHANGELOG.md`'s Phase 6 entry.

## Deployment

Static files — serve `index.html`/`app.js`/`crypto.js`/`gateway.js`/
`style.css` from any static host or CDN. Example nginx config serving
this alongside a reverse-proxied gateway is in
`../provisioning/vps-gateway/nginx-example.conf`.
