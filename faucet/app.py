#!/usr/bin/env python3
"""CodexaCoin testnet faucet.

Simple Flask app that pays out a fixed amount of testnet CAC to a
user-supplied address via RPC to a testnet codexacoind. Rate-limited per-IP
(in-memory, resets on restart) AND per-address (persisted in SQLite, so a
restart can't be used to bypass it). No external services, no API keys --
deliberately minimal so it's easy to audit and self-host.

Configuration is via environment variables (see README.md):
    CAC_RPC_HOST, CAC_RPC_PORT, CAC_RPC_USER, CAC_RPC_PASSWORD
    FAUCET_PAYOUT_CAC       (default: 10)
    FAUCET_COOLDOWN_HOURS   (default: 24)
    FAUCET_DB_PATH          (default: faucet.db next to this file)
    FAUCET_SECRET_KEY       (Flask session secret; generate a real one for prod)
"""
import http.client
import json
import os
import sqlite3
import time
from base64 import b64encode
from contextlib import contextmanager
from decimal import Decimal, InvalidOperation

from flask import Flask, jsonify, render_template, request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

COIN = 100_000_000

RPC_HOST = os.environ.get("CAC_RPC_HOST", "127.0.0.1")
RPC_PORT = int(os.environ.get("CAC_RPC_PORT", "26211"))
RPC_USER = os.environ.get("CAC_RPC_USER")
RPC_PASSWORD = os.environ.get("CAC_RPC_PASSWORD")
PAYOUT_CAC = Decimal(os.environ.get("FAUCET_PAYOUT_CAC", "10"))
COOLDOWN_HOURS = float(os.environ.get("FAUCET_COOLDOWN_HOURS", "24"))
# The `limits` library's rate-string parser rejects fractional counts
# (e.g. "1 per 24.0 hours" raises -- confirmed empirically that this
# silently disabled per-IP limiting entirely when passed a raw float).
# Express in whole minutes instead so any FAUCET_COOLDOWN_HOURS value
# (including fractional, e.g. "0.5") still produces a valid,
# non-degenerate integer rate string.
COOLDOWN_MINUTES = max(1, int(round(COOLDOWN_HOURS * 60)))
DB_PATH = os.environ.get("FAUCET_DB_PATH", os.path.join(os.path.dirname(__file__), "faucet.db"))

app = Flask(__name__)
app.config["SECRET_KEY"] = os.environ.get("FAUCET_SECRET_KEY", "dev-only-change-me")

limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=[],
    storage_uri="memory://",
)


def init_db():
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS claims (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                address TEXT NOT NULL,
                ip TEXT NOT NULL,
                amount_cac TEXT NOT NULL,
                txid TEXT,
                created_at REAL NOT NULL
            )
            """
        )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_claims_address ON claims(address)")
        conn.commit()


@contextmanager
def db():
    conn = sqlite3.connect(DB_PATH)
    try:
        yield conn
    finally:
        conn.close()


class RpcError(Exception):
    pass


def rpc_call(method, params=None):
    if not RPC_USER or not RPC_PASSWORD:
        raise RpcError("Faucet is not configured (missing CAC_RPC_USER/CAC_RPC_PASSWORD)")
    auth = "Basic " + b64encode(f"{RPC_USER}:{RPC_PASSWORD}".encode()).decode()
    payload = json.dumps({"jsonrpc": "1.0", "id": "faucet", "method": method, "params": params or []})
    conn = http.client.HTTPConnection(RPC_HOST, RPC_PORT, timeout=15)
    try:
        conn.request("POST", "/", payload, {"Content-Type": "application/json", "Authorization": auth})
        resp = conn.getresponse()
        body = json.loads(resp.read())
    finally:
        conn.close()
    if body.get("error"):
        raise RpcError(str(body["error"]))
    return body["result"]


def is_valid_testnet_address(address):
    """Delegate to the node's own validateaddress -- avoids duplicating
    base58/bech32 decoding logic (and its edge cases) in this app."""
    try:
        result = rpc_call("validateaddress", [address])
        return bool(result.get("isvalid"))
    except RpcError:
        return False


def address_last_claim(address):
    with db() as conn:
        row = conn.execute(
            "SELECT created_at FROM claims WHERE address = ? ORDER BY created_at DESC LIMIT 1",
            (address,),
        ).fetchone()
    return row[0] if row else None


def record_claim(address, ip, amount_cac, txid):
    with db() as conn:
        conn.execute(
            "INSERT INTO claims (address, ip, amount_cac, txid, created_at) VALUES (?, ?, ?, ?, ?)",
            (address, ip, str(amount_cac), txid, time.time()),
        )
        conn.commit()


@app.route("/")
def index():
    return render_template(
        "index.html",
        payout=PAYOUT_CAC,
        cooldown_hours=COOLDOWN_HOURS,
    )


@app.route("/claim", methods=["POST"])
@limiter.limit(lambda: f"1 per {COOLDOWN_MINUTES} minutes")
def claim():
    address = (request.form.get("address") or "").strip()
    # Honeypot: a hidden field real users never fill in. Bots that
    # autofill every form field will trip this; no CAPTCHA/external
    # service required for this level of abuse resistance.
    if request.form.get("website"):
        return jsonify({"ok": False, "error": "Request rejected."}), 400

    if not address:
        return jsonify({"ok": False, "error": "Address is required."}), 400

    if not is_valid_testnet_address(address):
        return jsonify({"ok": False, "error": "That doesn't look like a valid testnet CAC address."}), 400

    last_claim = address_last_claim(address)
    if last_claim is not None:
        elapsed_hours = (time.time() - last_claim) / 3600
        if elapsed_hours < COOLDOWN_HOURS:
            remaining = COOLDOWN_HOURS - elapsed_hours
            return jsonify({
                "ok": False,
                "error": f"That address already claimed recently. Try again in {remaining:.1f} hours.",
            }), 429

    try:
        txid = rpc_call("sendtoaddress", [address, float(PAYOUT_CAC)])
    except RpcError as e:
        app.logger.error("Faucet payout RPC failed: %s", e)
        return jsonify({"ok": False, "error": "Payout failed on our end -- please try again shortly."}), 502

    record_claim(address, get_remote_address(), PAYOUT_CAC, txid)
    return jsonify({"ok": True, "txid": txid, "amount": str(PAYOUT_CAC)})


@app.errorhandler(429)
def ratelimit_handler(e):
    return jsonify({"ok": False, "error": "Too many requests from this IP. Please slow down."}), 429


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")))
else:
    init_db()
