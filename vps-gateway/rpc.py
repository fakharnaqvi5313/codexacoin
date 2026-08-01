"""Minimal JSON-RPC client for codexacoind, matching ../faucet/app.py's
pattern (raw http.client, no external RPC library dependency)."""
import http.client
import json
import os
from base64 import b64encode

RPC_HOST = os.environ.get("CAC_RPC_HOST", "127.0.0.1")
RPC_PORT = int(os.environ.get("CAC_RPC_PORT", "16211"))
RPC_USER = os.environ.get("CAC_RPC_USER")
RPC_PASSWORD = os.environ.get("CAC_RPC_PASSWORD")
RPC_WALLET = os.environ.get("CAC_RPC_WALLET", "")


class RpcError(Exception):
    def __init__(self, code, message):
        self.code = code
        self.message = message
        super().__init__(f"{code}: {message}")


def call(method, params=None, wallet=None):
    if not RPC_USER or not RPC_PASSWORD:
        raise RpcError(-1, "Gateway is not configured (missing CAC_RPC_USER/CAC_RPC_PASSWORD)")
    path = "/"
    w = RPC_WALLET if wallet is None else wallet
    if w:
        path = f"/wallet/{w}"
    auth = "Basic " + b64encode(f"{RPC_USER}:{RPC_PASSWORD}".encode()).decode()
    payload = json.dumps({"jsonrpc": "1.0", "id": "gateway", "method": method, "params": params or []})
    conn = http.client.HTTPConnection(RPC_HOST, RPC_PORT, timeout=30)
    try:
        conn.request("POST", path, payload, {"Content-Type": "application/json", "Authorization": auth})
        resp = conn.getresponse()
        body = json.loads(resp.read())
    finally:
        conn.close()
    if body.get("error"):
        err = body["error"]
        raise RpcError(err.get("code"), err.get("message"))
    return body["result"]
