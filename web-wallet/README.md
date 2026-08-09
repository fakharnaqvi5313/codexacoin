# web-wallet

Phase 6 deliverable. A static, browser-based CodexaCoin wallet — no
build step, no bundler, no Node.js toolchain. Talks to `../vps-gateway/`
using the exact same REST contract (`../docs/mobile-api.md`) as the
mobile app (`../cac_wallet/`).

## Files

- `index.html` / `style.css` — markup and styling, no framework.
- `app.js` — all UI logic and event wiring.
- `crypto.js` — address encoding, transaction signing, N-of-M multisig
  primitives (mirrors `cac_wallet/lib/crypto/*.dart`).
- `gateway.js` — REST client for `vps-gateway`.
- `qr.js` — QR code generation (receive) and camera-based scanning
  (send), isolating the two CDN-loaded dependencies (`qrcode`, `jsqr`)
  in one place, same convention `crypto.js` uses for its own imports.
- `storage.js` — optional PIN-based encryption for the recovery phrase
  at rest (PBKDF2 + AES-GCM via the browser's Web Crypto API).

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

Setting a PIN (Settings tab, once a wallet exists) closes part of that
gap: `storage.js` encrypts the mnemonic with a PBKDF2-derived AES-GCM
key before it touches `localStorage`, replacing the plaintext copy.
That's real protection against someone reading storage directly — not a
UI-only lock — but it's still only as strong as the PIN itself, and
offers nothing once the wallet is unlocked in an open tab. Said plainly
in-app for the same reason as everything else here: don't oversell what
a security feature actually does.

## Other features

- **QR codes** — the receive screen renders one for the active address;
  the send screen can scan one via the device camera (needs camera
  permission; degrades to a clear error message, not a blank screen, if
  denied or unavailable).
- **Address book** — labelled addresses saved in `localStorage`, usable
  as a one-click fill on the send screen.
- **Transaction detail** — tapping a history row shows a full breakdown
  (status, confirmations, coinstake/reward if applicable, inputs,
  outputs) fetched from the gateway's `/tx/<txid>` endpoint.
- **Multiple addresses** — "New address" on the Receive screen derives
  the next BIP44 index and adds it to this wallet's known set; balance,
  UTXOs, and history are combined across every address it's generated
  *on this browser*. This is not BIP44 gap-limit discovery — restoring
  the same phrase on a different browser starts back at index 0 and
  won't find addresses generated elsewhere. Said explicitly in the app
  (Receive screen) as well as here.
- **Multisig (N-of-M)** — a UI over `crypto.js`'s existing multisig
  primitives: generate a shared address, propose a spend, and sign
  sequentially (cosigner A signs the proposal JSON, passes it to B, and
  so on) until enough signatures are collected to broadcast. Proposals
  are exchanged out-of-band (email, a shared file) — nothing here
  transmits them. Index 0's key is always this wallet's multisig
  identity, independent of whichever address is "active" for receiving.

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

## Verification (2026-08-04 feature batch)

Tested in a real browser end to end, not just read for correctness:
wallet creation, receive-screen QR rendering, generating a second
address and confirming the home screen combines balance across both,
address-book add/use, multisig address generation (redeem script and
P2SH address verified byte-for-byte correct), PIN set → reload → lock
overlay persists → wrong PIN rejected → correct PIN decrypts to the
identical wallet → lock-now → remove-PIN, transaction-detail modal
(mocked gateway response, both output-address JSON shapes), and the
QR scanner's camera-denied error path. Found and fixed one real bug in
the process: `loadSettings()` cleared the PIN success/error message
immediately after `btn-set-pin`/`btn-remove-pin` set it, so neither
message was ever actually visible — split into a message-clearing path
(screen entry) and a card-visibility-only path (`refreshLockCardVisibility`,
used after actions). Multi-key transaction signing and the full
multisig propose → sign → sign → finalize round trip were verified
directly against `crypto.js` (can't exercise real broadcasts without
funds/a live gateway).

## Deployment

Static files — serve `index.html`/`app.js`/`crypto.js`/`gateway.js`/
`qr.js`/`storage.js`/`style.css` from any static host or CDN. Example
nginx config serving this alongside a reverse-proxied gateway is in
`../provisioning/vps-gateway/nginx-example.conf`.
