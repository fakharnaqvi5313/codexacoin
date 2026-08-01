#!/bin/bash
# CodexaCoin mobile/web gateway (vps-gateway) provisioning script.
#
# Target: fresh Ubuntu 22.04/24.04 or Debian 12 VPS, with a fully-synced
# codexacoind already running on it (or reachable via CAC_RPC_HOST/PORT).
# Idempotent -- safe to re-run.
#
# This installs BOTH systemd units: gateway.service (the REST API itself,
# behind gunicorn) and gateway-watcher.timer (runs the staking pool
# watcher pass every 60s -- see ../../vps-gateway/staking.py's module
# docstring for what that watcher does and why).
#
# What this does NOT provision: the codexacoind node itself (see
# ../seed-node/), or the pool's staking wallet's backup/custody
# procedure, which is an operational decision for whoever runs this in
# production, not something a provisioning script should make for them.
#
# Usage (as root or via sudo):
#   REPO_URL=https://github.com/codexacoin/codexacoin-cloud.git \
#   REPO_REF=main \
#   CAC_RPC_USER=gatewayrpc \
#   CAC_RPC_PASSWORD=changeme \
#   ./provision.sh

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/codexacoin/codexacoin-cloud.git}"
REPO_REF="${REPO_REF:-main}"
CAC_RPC_HOST="${CAC_RPC_HOST:-127.0.0.1}"
CAC_RPC_PORT="${CAC_RPC_PORT:-16211}"
CAC_RPC_USER="${CAC_RPC_USER:?Set CAC_RPC_USER (matches codexacoind's rpcuser=)}"
CAC_RPC_PASSWORD="${CAC_RPC_PASSWORD:?Set CAC_RPC_PASSWORD (matches codexacoind's rpcpassword=)}"
CAC_NETWORK="${CAC_NETWORK:-mainnet}"
GATEWAY_CORS_ORIGINS="${GATEWAY_CORS_ORIGINS:-*}"
CAC_USER="cac-gateway"
CAC_GROUP="cac-gateway"
BUILD_DIR="/opt/cac-gateway"
DATA_DIR="/var/lib/cac-gateway"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root (or with sudo)." >&2
    exit 1
fi

echo "=== [1/7] Installing system dependencies ==="
apt-get update
apt-get install -y python3 python3-venv python3-dev build-essential git

echo "=== [2/7] Creating service user ==="
if ! id "$CAC_USER" >/dev/null 2>&1; then
    useradd --system --create-home --shell /usr/sbin/nologin --user-group "$CAC_USER"
fi
mkdir -p "$DATA_DIR"
chown "$CAC_USER:$CAC_GROUP" "$DATA_DIR"

echo "=== [3/7] Fetching gateway source ==="
if [ -d "$BUILD_DIR/.git" ]; then
    git -C "$BUILD_DIR" fetch --depth 1 origin "$REPO_REF"
    git -C "$BUILD_DIR" checkout FETCH_HEAD -- vps-gateway
else
    rm -rf "$BUILD_DIR"
    git clone --depth 1 --branch "$REPO_REF" --no-checkout "$REPO_URL" "$BUILD_DIR"
    git -C "$BUILD_DIR" sparse-checkout set vps-gateway
    git -C "$BUILD_DIR" checkout "$REPO_REF"
fi
# app.py etc. live at the repo root of vps-gateway/, not BUILD_DIR itself
BUILD_DIR="$BUILD_DIR/vps-gateway"

echo "=== [4/7] Building venv and installing dependencies ==="
python3 -m venv "$BUILD_DIR/venv"
"$BUILD_DIR/venv/bin/pip" install --quiet --upgrade pip
"$BUILD_DIR/venv/bin/pip" install --quiet -r "$BUILD_DIR/requirements.txt"

echo "=== [5/7] Writing environment config ==="
JWT_SECRET="$(openssl rand -hex 32)"
cat > /etc/cac-gateway.conf <<EOF
CAC_RPC_HOST=$CAC_RPC_HOST
CAC_RPC_PORT=$CAC_RPC_PORT
CAC_RPC_USER=$CAC_RPC_USER
CAC_RPC_PASSWORD=$CAC_RPC_PASSWORD
CAC_NETWORK=$CAC_NETWORK
GATEWAY_DB_PATH=$DATA_DIR/gateway.db
GATEWAY_JWT_SECRET=$JWT_SECRET
GATEWAY_CORS_ORIGINS=$GATEWAY_CORS_ORIGINS
EOF
chmod 640 /etc/cac-gateway.conf
chown "root:$CAC_GROUP" /etc/cac-gateway.conf
echo "Generated a fresh GATEWAY_JWT_SECRET in /etc/cac-gateway.conf -- back this up, rotating it invalidates every issued token."

echo "=== [6/7] Installing systemd units ==="
install -m 644 "$SCRIPT_DIR/gateway.service" /etc/systemd/system/gateway.service
install -m 644 "$SCRIPT_DIR/gateway-watcher.service" /etc/systemd/system/gateway-watcher.service
install -m 644 "$SCRIPT_DIR/gateway-watcher.timer" /etc/systemd/system/gateway-watcher.timer
sed -i "s|__BUILD_DIR__|$BUILD_DIR|g; s|__USER__|$CAC_USER|g; s|__GROUP__|$CAC_GROUP|g" \
    /etc/systemd/system/gateway.service /etc/systemd/system/gateway-watcher.service
systemctl daemon-reload

echo "=== [7/7] Starting services ==="
systemctl enable gateway gateway-watcher.timer
systemctl restart gateway
systemctl restart gateway-watcher.timer

echo ""
echo "Done. journalctl -u gateway -f to watch the API; journalctl -u"
echo "gateway-watcher -f to watch staking pool watcher passes (one per"
echo "minute). Reverse-proxy port 8080 behind nginx/Caddy with TLS before"
echo "exposing this publicly -- this script does not set that up. (Unlike"
echo "../electrumx/provision.sh, which provisions its own TLS certificate"
echo "directly: electrumx has native SSL support with no reverse-proxy"
echo "convention, whereas gunicorn/Flask APIs are normally TLS-terminated"
echo "by a proxy in front of them, so that's left as a separate step here.)"
