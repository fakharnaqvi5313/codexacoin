#!/usr/bin/env python3
"""CodexaCoin block explorer backend.

Public, read-only, no authentication and no wallet keys -- a
deliberately separate, lower-trust service from ../vps-gateway/ (which
holds the staking pool's real private keys). See README.md for why this
is its own service rather than a set of endpoints bolted onto the
gateway.

Backend: direct codexacoind RPC, same choice and same reasoning as
../vps-gateway/ (see PARAMETERS.md section 13.1) -- txindex=1 is already
enabled on this node (confirmed via getindexinfo), so arbitrary
block/transaction lookups by hash/txid work natively with no extra
indexing infrastructure.

Address lookups use `scantxoutset`, a stateless full-UTXO-set scan for a
descriptor, rather than importing the address into a wallet
(../vps-gateway/app.py's approach) -- appropriate here specifically
because the explorer must be able to look up *any* address a visitor
types in without accumulating permanent wallet state for each one.
Known limitation: scantxoutset only sees the *current* UTXO set, so this
gives accurate current balance/UTXOs but NOT historical (already-spent)
transactions for an address -- that needs a real index (electrumx-cac,
still blocked locally per PARAMETERS.md section 11). Documented here and
in the API response itself, not silently overclaimed.

Configuration is via environment variables:
    CAC_RPC_HOST, CAC_RPC_PORT, CAC_RPC_USER, CAC_RPC_PASSWORD
    EXPLORER_CORS_ORIGINS  (default: *)
"""
import os
import re

from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

import rpc
from rpc import RpcError

COIN = 100_000_000
# PARAMETERS.md section 5: 500-block PoW founder premine window, flat
# 28,000,000 CAC/block; PoS (coin-age-proportional, section 6) after that.
LAST_POW_BLOCK = 500
POW_BLOCK_SUBSIDY_SATS = 28_000_000 * COIN
PREMINE_TOTAL_SATS = 500 * POW_BLOCK_SUBSIDY_SATS  # == 14,000,000,000 CAC

app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": os.environ.get("EXPLORER_CORS_ORIGINS", "*")}})
# Fully public, unauthenticated, no per-user identity to key off of --
# rate-limit by IP as the only real abuse control available here (unlike
# vps-gateway, which additionally gates behind login).
limiter = Limiter(get_remote_address, app=app, default_limits=["120 per minute"], storage_uri="memory://")


def error(message, status=400):
    return jsonify({"error": message}), status


def is_coinstake_tx(tx):
    return (
        len(tx["vin"]) > 0
        and "coinbase" not in tx["vin"][0]
        and len(tx["vout"]) >= 2
        and float(tx["vout"][0]["value"]) == 0
        and tx["vout"][0]["scriptPubKey"].get("hex", "") == ""
    )


def summarize_tx(tx, block_time=None):
    is_coinbase = "coinbase" in tx["vin"][0] if tx["vin"] else False
    is_coinstake = is_coinstake_tx(tx)
    out_total_sats = sum(round(o["value"] * COIN) for o in tx["vout"])
    return {
        "txid": tx["txid"],
        "is_coinbase": is_coinbase,
        "is_coinstake": is_coinstake,
        "vin_count": len(tx["vin"]),
        "vout_count": len(tx["vout"]),
        "output_total_satoshis": str(out_total_sats),
        "time": tx.get("time", block_time),
    }


@app.route("/api/stats")
def stats():
    info = rpc.call("getblockchaininfo")
    height = info["blocks"]
    mined_pow_blocks = min(height, LAST_POW_BLOCK)
    minted_from_pow = mined_pow_blocks * POW_BLOCK_SUBSIDY_SATS
    return jsonify({
        "height": height,
        "best_block_hash": info["bestblockhash"],
        "difficulty": info["difficulty"],
        "chain": info["chain"],
        "pow_window_blocks": LAST_POW_BLOCK,
        "pow_blocks_mined": mined_pow_blocks,
        "pow_phase_complete": height >= LAST_POW_BLOCK,
        "premine_total_satoshis": str(PREMINE_TOTAL_SATS),
        "minted_from_pow_satoshis": str(minted_from_pow),
        # PoS rewards (post block 500) are coin-age-proportional and paid
        # per-coinstake, not a fixed per-block subsidy -- there's no
        # simple "total minted so far" formula for that phase the way
        # there is for the flat PoW window (see PARAMETERS.md section 6).
        # Deliberately not estimated here rather than shown as a
        # possibly-wrong number.
    })


@app.route("/api/block/<ident>")
def block_detail(ident):
    try:
        if re.fullmatch(r"[0-9]+", ident):
            block_hash = rpc.call("getblockhash", [int(ident)])
        else:
            block_hash = ident
        block = rpc.call("getblock", [block_hash, 2])
    except RpcError:
        return error("No such block", 404)

    txs = [summarize_tx(tx, block["time"]) for tx in block["tx"]]
    is_pos = block.get("flags") == "proof-of-stake" or (len(txs) > 0 and txs[0]["is_coinstake"])
    return jsonify({
        "hash": block["hash"],
        "height": block["height"],
        "time": block["time"],
        "difficulty": block["difficulty"],
        "bits": block["bits"],
        "version": block["version"],
        "merkleroot": block["merkleroot"],
        "previousblockhash": block.get("previousblockhash"),
        "nextblockhash": block.get("nextblockhash"),
        "is_proof_of_stake": is_pos,
        "tx_count": len(txs),
        "transactions": txs,
    })


@app.route("/api/tx/<txid>")
def tx_detail(txid):
    try:
        tx = rpc.call("getrawtransaction", [txid, True])
    except RpcError:
        return error("No such transaction", 404)

    is_coinstake = is_coinstake_tx(tx)
    is_coinbase = "coinbase" in tx["vin"][0] if tx["vin"] else False
    reward_satoshis = None
    if is_coinstake:
        out_total = sum(round(o["value"] * COIN) for o in tx["vout"])
        in_total = 0
        for vin in tx["vin"]:
            prevtx = rpc.call("getrawtransaction", [vin["txid"], True])
            in_total += round(prevtx["vout"][vin["vout"]]["value"] * COIN)
        reward_satoshis = out_total - in_total

    height = None
    if "blockhash" in tx:
        block = rpc.call("getblock", [tx["blockhash"], 1])
        height = block["height"]

    return jsonify({
        "txid": txid,
        "height": height,
        "blockhash": tx.get("blockhash"),
        "confirmations": tx.get("confirmations", 0),
        "time": tx.get("time"),
        "is_coinbase": is_coinbase,
        "is_coinstake": is_coinstake,
        "reward_satoshis": str(reward_satoshis) if reward_satoshis is not None else None,
        "vin": tx["vin"],
        "vout": tx["vout"],
    })


@app.route("/api/address/<address>")
@limiter.limit("10 per minute")  # scantxoutset is a full UTXO-set scan -- expensive, limit harder
def address_detail(address):
    try:
        result = rpc.call("scantxoutset", ["start", [f"addr({address})"]])
    except RpcError as e:
        return error(f"Lookup failed: {e.message}", 400)
    if not result.get("success"):
        return error("Scan did not complete, try again", 503)

    utxos = [
        {"txid": u["txid"], "vout": u["vout"], "value_satoshis": str(round(u["amount"] * COIN)),
         "height": u.get("height"), "is_coinbase_or_coinstake": u.get("coinbase", False)}
        for u in result["unspents"]
    ]
    balance_satoshis = sum(int(u["value_satoshis"]) for u in utxos)
    return jsonify({
        "address": address,
        "balance_satoshis": str(balance_satoshis),
        "utxo_count": len(utxos),
        "utxos": utxos,
        "scanned_at_height": result["height"],
        "note": "Current balance/UTXOs only -- this explorer has no full "
                "transaction-history index (see app.py's module docstring); "
                "spent/historical transactions for this address aren't shown here.",
    })


@app.route("/api/search")
def search():
    q = request.args.get("q", "").strip()
    if not q:
        return error("Provide ?q=<height|block hash|txid|address>")

    if re.fullmatch(r"[0-9]+", q):
        return jsonify({"type": "block", "id": q})
    if re.fullmatch(r"[0-9a-fA-F]{64}", q):
        # Disambiguate block hash vs txid by trying getblock first (cheap,
        # since we already have txindex for the tx fallback).
        try:
            rpc.call("getblock", [q, 1])
            return jsonify({"type": "block", "id": q})
        except RpcError:
            pass
        try:
            rpc.call("getrawtransaction", [q, True])
            return jsonify({"type": "tx", "id": q})
        except RpcError:
            return error("No block or transaction found with that hash", 404)
    # Anything else is treated as an address -- decodeAddress-style
    # validation happens client-side (crypto.js, shared with web-wallet);
    # the backend just tries the scan and reports failure if it's not
    # actually a valid/known address.
    return jsonify({"type": "address", "id": q})


RICHLIST_MAX_BLOCKS = int(os.environ.get("EXPLORER_RICHLIST_MAX_BLOCKS", "5000"))


@app.route("/api/richlist")
@limiter.limit("6 per minute")  # this is a real block-scanning computation, not a cheap lookup -- see its own comment
def richlist():
    # No general address index exists (see module docstring), so this
    # builds one on the fly by walking every block's transactions:
    # credit each output's address, debit each non-coinbase input's
    # previous output's address (resolved via txindex). Correct for the
    # whole chain, but genuinely O(blocks x transactions) -- bounded by
    # EXPLORER_RICHLIST_MAX_BLOCKS (walks the *last* N blocks only once
    # the chain exceeds that, silently becoming an approximation over
    # only recent history rather than a wrong full-chain answer). Fine
    # for this project's current chain size; a real address index
    # (electrumx-cac, PARAMETERS.md section 11) is the right fix before
    # this matters on a mature chain -- this isn't a replacement for
    # that, just what's honestly buildable without one right now.
    try:
        limit = min(int(request.args.get("limit", "20")), 100)
    except ValueError:
        return error("invalid-request", "limit must be an integer")

    height = rpc.call("getblockchaininfo")["blocks"]
    start_height = max(0, height - RICHLIST_MAX_BLOCKS + 1)
    truncated = start_height > 0

    balances = {}
    for h in range(start_height, height + 1):
        block_hash = rpc.call("getblockhash", [h])
        block = rpc.call("getblock", [block_hash, 2])
        for tx in block["tx"]:
            for vout in tx["vout"]:
                addr = vout["scriptPubKey"].get("address")
                if not addr:
                    continue
                balances[addr] = balances.get(addr, 0) + round(vout["value"] * COIN)
            if "coinbase" in tx["vin"][0]:
                continue
            for vin in tx["vin"]:
                # Only resolvable if the spent output's own block is
                # within our scan window (or txindex has it regardless --
                # it does, since txindex covers the whole chain even
                # when our balance walk is windowed to recent blocks).
                try:
                    prevtx = rpc.call("getrawtransaction", [vin["txid"], True])
                except RpcError:
                    continue
                prevout = prevtx["vout"][vin["vout"]]
                addr = prevout["scriptPubKey"].get("address")
                if not addr:
                    continue
                balances[addr] = balances.get(addr, 0) - round(prevout["value"] * COIN)

    ranked = sorted(balances.items(), key=lambda kv: kv[1], reverse=True)
    ranked = [(a, b) for a, b in ranked if b > 0][:limit]
    return jsonify({
        "addresses": [{"address": a, "balance_satoshis": str(b)} for a, b in ranked],
        "scanned_from_height": start_height,
        "scanned_to_height": height,
        "truncated": truncated,
    })


@app.route("/api/supply-series")
def supply_series():
    # Exact, not scanned: the PoW premine window (section 5) pays a
    # fixed, known subsidy per block, so total minted at any height
    # within that window is a direct computation, not something that
    # needs walking every block's coinbase like richlist() does. Once
    # the chain passes the PoW window into PoS (coin-age-proportional,
    # section 6, no fixed per-block amount), this endpoint stops being
    # able to give an exact figure the same cheap way -- see the "false"
    # pow_phase_complete-gated field below for how that's surfaced
    # rather than silently extrapolated wrong.
    info = rpc.call("getblockchaininfo")
    height = info["blocks"]
    buckets = min(50, max(1, height))
    step = max(1, height // buckets)
    points = []
    for h in range(0, height + 1, step):
        mined_pow_blocks = min(h, LAST_POW_BLOCK)
        points.append({"height": h, "minted_satoshis": str(mined_pow_blocks * POW_BLOCK_SUBSIDY_SATS)})
    if points[-1]["height"] != height:
        mined_pow_blocks = min(height, LAST_POW_BLOCK)
        points.append({"height": height, "minted_satoshis": str(mined_pow_blocks * POW_BLOCK_SUBSIDY_SATS)})
    return jsonify({
        "points": points,
        "pow_phase_complete": height >= LAST_POW_BLOCK,
        "note": "Exact for the PoW premine window (height <= 500). Once the "
                "chain is in its PoS phase, total supply has no fixed "
                "per-block formula to compute this way -- see PARAMETERS.md "
                "section 6.",
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081, debug=False)
