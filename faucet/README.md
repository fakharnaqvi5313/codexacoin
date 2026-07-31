# CodexaCoin testnet faucet

Minimal Flask app that pays out a fixed amount of testnet CAC per request,
rate-limited per-IP and per-address. No external services (no CAPTCHA
provider, no Redis) — a honeypot field handles basic bot resistance, and
rate-limit state is either in-memory (per-IP) or SQLite (per-address,
survives restarts).

## Setup

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

The faucet needs RPC access to a **funded** testnet `codexacoind` wallet.
Funding that wallet is a manual, deliberate operator action — send it CAC
from whoever holds the testnet premine (see PARAMETERS.md's "How VPS
deployment actually works" discussion for why this app never mines or
holds premine itself).

```bash
export CAC_RPC_HOST=127.0.0.1
export CAC_RPC_PORT=26211
export CAC_RPC_USER=<rpc username, e.g. from -rpcuser or rpcauth.py>
export CAC_RPC_PASSWORD=<rpc password>
export FAUCET_PAYOUT_CAC=10          # optional, default 10
export FAUCET_COOLDOWN_HOURS=24      # optional, default 24
export FAUCET_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")

python3 app.py
```

Visit `http://localhost:5000`.

## How it works

- `GET /` — the claim form.
- `POST /claim` — `address` form field; validates the address via the
  node's own `validateaddress` RPC (no address-decoding logic duplicated
  here), checks the honeypot field is empty, checks SQLite for a recent
  claim from that address, then calls `sendtoaddress` and records the
  claim.
- Per-IP rate limiting (`flask-limiter`, in-memory storage) additionally
  caps requests to one per `FAUCET_COOLDOWN_HOURS` per source IP,
  independent of the per-address check.

## Production notes (not fully hardened here — see below)

This is deliberately minimal, matching the spec's "simple Flask app...with
rate limiting" ask. Before exposing this publicly, at minimum:

- Run behind a real WSGI server (gunicorn/uwsgi) + reverse proxy (nginx/
  Caddy) with TLS — `app.run()` is dev-only.
- Move `FLASK_SECRET_KEY` to a real secret, not the `dev-only-change-me`
  default.
- In-memory per-IP rate limiting resets on process restart and doesn't
  share state across multiple worker processes — for a multi-worker
  production deployment, point `Limiter(storage_uri=...)` at Redis or
  another shared backend instead.
- Consider a real CAPTCHA (hCaptcha/Turnstile) if the honeypot proves
  insufficient against real-world bot traffic.
- Keep the payout wallet's balance modest and top it up manually/on a
  schedule rather than granting it access to the full premine — limits
  blast radius if the faucet host is ever compromised.
- Put the faucet's RPC credentials in a secrets manager / systemd
  `EnvironmentFile=` with restricted permissions, not a shell export in a
  long-lived session.
