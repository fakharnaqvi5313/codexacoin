"""Minimal JSON-RPC client for codexacoind. Identical pattern to
../vps-gateway/rpc.py and ../faucet/app.py's -- duplicated rather than
shared as a library, since each of this project's services (electrumx-cac,
vps-gateway, explorer) is deliberately independently deployable, matching
how they're documented and provisioned separately.

No RPC_WALLET default here (unlike vps-gateway's): the explorer only ever
calls wallet-agnostic RPCs (getblock, getrawtransaction, etc.) -- it holds
no keys and needs no wallet context, which is the whole point of it being
a separate, lower-trust service from the gateway (see README.md)."""
import http.client
import json
import os
from base64 import b64encode

RPC_HOST = os.environ.get("CAC_RPC_HOST", "127.0.0.1")
RPC_PORT = int(os.environ.get("CAC_RPC_PORT", "16211"))
RPC_USER = os.environ.get("CAC_RPC_USER")
RPC_PASSWORD = os.environ.get("CAC_RPC_PASSWORD")


class RpcError(Exception):
    def __init__(self, code, message):
        self.code = code
        self.message = message
        super().__init__(f"{code}: {message}")


def call(method, params=None):
    if not RPC_USER or not RPC_PASSWORD:
        raise RpcError(-1, "Explorer is not configured (missing CAC_RPC_USER/CAC_RPC_PASSWORD)")
    auth = "Basic " + b64encode(f"{RPC_USER}:{RPC_PASSWORD}".encode()).decode()
    payload = json.dumps({"jsonrpc": "1.0", "id": "explorer", "method": method, "params": params or []})
    conn = http.client.HTTPConnection(RPC_HOST, RPC_PORT, timeout=30)
    try:
        conn.request("POST", "/", payload, {"Content-Type": "application/json", "Authorization": auth})
        resp = conn.getresponse()
        body = json.loads(resp.read())
    finally:
        conn.close()
    if body.get("error"):
        err = body["error"]
        raise RpcError(err.get("code"), err.get("message"))
    return body["result"]
