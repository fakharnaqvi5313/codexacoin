#!/bin/bash
# CodexaCoin block explorer provisioning script.
#
# Target: fresh Ubuntu 22.04/24.04 or Debian 12 VPS, with a fully-synced
# codexacoind already running on it (or reachable via CAC_RPC_HOST/PORT)
# and txindex=1 set (required -- see explorer/app.py's module docstring).
# Idempotent -- safe to re-run.
#
# Unlike ../vps-gateway/provision.sh, this service holds no keys and
# needs no persistent data directory -- it's stateless, read-only RPC
# passthrough plus a static frontend, so there's no wallet/database setup
# step here.
#
# Usage (as root or via sudo):
#   REPO_URL=https://github.com/codexacoin/codexacoin-cloud.git \
#   REPO_REF=main \
#   CAC_RPC_USER=explorerrpc \
#   CAC_RPC_PASSWORD=changeme \
#   ./provision.sh

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/codexacoin/codexacoin-cloud.git}"
REPO_REF="${REPO_REF:-main}"
CAC_RPC_HOST="${CAC_RPC_HOST:-127.0.0.1}"
CAC_RPC_PORT="${CAC_RPC_PORT:-16211}"
CAC_RPC_USER="${CAC_RPC_USER:?Set CAC_RPC_USER (matches codexacoind's rpcuser=)}"
CAC_RPC_PASSWORD="${CAC_RPC_PASSWORD:?Set CAC_RPC_PASSWORD (matches codexacoind's rpcpassword=)}"
EXPLORER_CORS_ORIGINS="${EXPLORER_CORS_ORIGINS:-*}"
CAC_USER="cac-explorer"
CAC_GROUP="cac-explorer"
BUILD_DIR="/opt/cac-explorer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root (or with sudo)." >&2
    exit 1
fi

echo "=== [1/6] Checking txindex is enabled ==="
# Best-effort check only -- codexacoind may be on a different host
# (CAC_RPC_HOST != 127.0.0.1), in which case this just can't confirm it
# locally and the script proceeds anyway.
if [ "$CAC_RPC_HOST" = "127.0.0.1" ] && command -v codexacoin-cli >/dev/null 2>&1; then
    if ! codexacoin-cli -rpcuser="$CAC_RPC_USER" -rpcpassword="$CAC_RPC_PASSWORD" getindexinfo 2>/dev/null | grep -q '"txindex"'; then
        echo "WARNING: txindex does not appear to be enabled on this node. Add"
        echo "txindex=1 to codexacoin.conf and restart codexacoind, or block/tx"
        echo "lookups by hash/txid will fail for anything not in the wallet."
    fi
fi

echo "=== [2/6] Installing system dependencies ==="
apt-get update
apt-get install -y python3 python3-venv python3-dev build-essential git

echo "=== [3/6] Creating service user ==="
if ! id "$CAC_USER" >/dev/null 2>&1; then
    useradd --system --create-home --shell /usr/sbin/nologin --user-group "$CAC_USER"
fi

echo "=== [4/6] Fetching explorer source ==="
if [ -d "$BUILD_DIR/.git" ]; then
    git -C "$BUILD_DIR" fetch --depth 1 origin "$REPO_REF"
    git -C "$BUILD_DIR" checkout FETCH_HEAD -- explorer
else
    rm -rf "$BUILD_DIR"
    git clone --depth 1 --branch "$REPO_REF" --no-checkout "$REPO_URL" "$BUILD_DIR"
    git -C "$BUILD_DIR" sparse-checkout set explorer
    git -C "$BUILD_DIR" checkout "$REPO_REF"
fi
BUILD_DIR="$BUILD_DIR/explorer"
chown -R "$CAC_USER:$CAC_GROUP" "$BUILD_DIR"

echo "=== [5/6] Building venv and writing config ==="
python3 -m venv "$BUILD_DIR/venv"
"$BUILD_DIR/venv/bin/pip" install --quiet --upgrade pip
"$BUILD_DIR/venv/bin/pip" install --quiet -r "$BUILD_DIR/requirements.txt"
cat > /etc/cac-explorer.conf <<EOF
CAC_RPC_HOST=$CAC_RPC_HOST
CAC_RPC_PORT=$CAC_RPC_PORT
CAC_RPC_USER=$CAC_RPC_USER
CAC_RPC_PASSWORD=$CAC_RPC_PASSWORD
EXPLORER_CORS_ORIGINS=$EXPLORER_CORS_ORIGINS
EOF
chmod 640 /etc/cac-explorer.conf
chown "root:$CAC_GROUP" /etc/cac-explorer.conf

echo "=== [6/6] Installing systemd unit ==="
install -m 644 "$SCRIPT_DIR/explorer.service" /etc/systemd/system/explorer.service
sed -i "s|__BUILD_DIR__|$BUILD_DIR|g; s|__USER__|$CAC_USER|g; s|__GROUP__|$CAC_GROUP|g" \
    /etc/systemd/system/explorer.service
systemctl daemon-reload
systemctl enable explorer
systemctl restart explorer

echo ""
echo "Done. journalctl -u explorer -f to watch it. Serve explorer/index.html,"
echo "app.js, style.css as static files (nginx, same pattern as"
echo "../vps-gateway/nginx-example.conf) and reverse-proxy /api/ to"
echo "127.0.0.1:8081 -- explorer/app.js's API_BASE defaults to that same"
echo "origin's /api path when served this way (override via localStorage"
echo "'cac_explorer_api' otherwise)."
