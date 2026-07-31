#!/bin/bash
# CodexaCoin Electrum server (electrumx-cac) provisioning script.
#
# Target: fresh Ubuntu 22.04/24.04 or Debian 12 VPS, with a fully-synced
# codexacoind already running on it (or reachable via DAEMON_URL) --
# txindex is required (this build's default) since electrumx needs full
# transaction lookups, not just UTXO-set queries. Idempotent -- safe to
# re-run.
#
# Native TLS support: electrumx has its own SSL_CERTFILE/SSL_KEYFILE
# config, no nginx/stunnel reverse-proxy needed. This script provisions a
# Let's Encrypt certificate via certbot in standalone mode.
#
# Usage (as root or via sudo):
#   REPO_URL=https://github.com/codexacoin/electrumx-cac.git \
#   REPO_REF=master \
#   PUBLIC_HOSTNAME=electrum1.codexacoin.example \
#   NETWORK=testnet \
#   DAEMON_URL="http://rpcuser:rpcpassword@127.0.0.1:26211/" \
#   ./provision.sh
#
# NETWORK must be one of: mainnet, testnet, regtest (matches the COIN/NET
# electrumx env vars via the lookup table below -- see
# src/electrumx/lib/coins.py's CodexaCoin/CodexaCoinTestnet/
# CodexaCoinRegtest classes in the electrumx-cac fork).

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/codexacoin/electrumx-cac.git}"
REPO_REF="${REPO_REF:-master}"
PUBLIC_HOSTNAME="${PUBLIC_HOSTNAME:?Set PUBLIC_HOSTNAME (e.g. electrum1.codexacoin.example)}"
NETWORK="${NETWORK:-testnet}"
DAEMON_URL="${DAEMON_URL:?Set DAEMON_URL, e.g. http://rpcuser:rpcpassword@127.0.0.1:26211/}"
DB_ENGINE="${DB_ENGINE:-leveldb}"
CAC_USER="electrumx"
CAC_GROUP="electrumx"
BUILD_DIR="/opt/electrumx-cac"
DATA_DIR="/var/lib/electrumx-cac"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root (or with sudo)." >&2
    exit 1
fi

case "$NETWORK" in
    mainnet)  COIN=CodexaCoin;         PUBLIC_TCP_PORT=50001; PUBLIC_SSL_PORT=50002 ;;
    testnet)  COIN=CodexaCoinTestnet;  PUBLIC_TCP_PORT=51001; PUBLIC_SSL_PORT=51002 ;;
    regtest)  COIN=CodexaCoinRegtest;  PUBLIC_TCP_PORT=52001; PUBLIC_SSL_PORT=52002 ;;
    *) echo "NETWORK must be mainnet, testnet, or regtest (got: $NETWORK)" >&2; exit 1 ;;
esac

echo "=== [1/7] Installing system dependencies ==="
apt-get update
apt-get install -y python3 python3-venv python3-dev build-essential git \
    certbot

if [ "$DB_ENGINE" = "leveldb" ]; then
    apt-get install -y libleveldb-dev
else
    apt-get install -y librocksdb-dev
fi

echo "=== [2/7] Creating service user ==="
if ! id "$CAC_USER" >/dev/null 2>&1; then
    useradd --system --create-home --shell /usr/sbin/nologin --user-group "$CAC_USER"
fi
mkdir -p "$DATA_DIR"
chown "$CAC_USER:$CAC_GROUP" "$DATA_DIR"

echo "=== [3/7] Fetching electrumx-cac source ==="
if [ -d "$BUILD_DIR/.git" ]; then
    git -C "$BUILD_DIR" fetch --depth 1 origin "$REPO_REF"
    git -C "$BUILD_DIR" checkout FETCH_HEAD
else
    rm -rf "$BUILD_DIR"
    git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$BUILD_DIR"
fi

echo "=== [4/7] Building venv and installing (with $DB_ENGINE extra) ==="
python3 -m venv "$BUILD_DIR/venv"
"$BUILD_DIR/venv/bin/pip" install --quiet --upgrade pip
"$BUILD_DIR/venv/bin/pip" install --quiet -e "$BUILD_DIR[$DB_ENGINE]"

echo "=== [5/7] Obtaining TLS certificate (Let's Encrypt, standalone) ==="
if [ ! -f "/etc/letsencrypt/live/$PUBLIC_HOSTNAME/fullchain.pem" ]; then
    certbot certonly --standalone --non-interactive --agree-tos \
        -m "admin@${PUBLIC_HOSTNAME#*.}" -d "$PUBLIC_HOSTNAME" \
        --deploy-hook "systemctl restart electrumx-cac" || \
        echo "WARNING: certbot failed (DNS for $PUBLIC_HOSTNAME not pointed here yet?). Continuing without SSL for now -- rerun once DNS is live."
fi

echo "=== [6/7] Writing environment config ==="
cat > /etc/electrumx-cac.conf <<EOF
# CodexaCoin Electrum server config. See PARAMETERS.md / docs/mobile-api.md
# for what these values mean; edit and re-run 'systemctl restart electrumx-cac'.
DB_DIRECTORY=$DATA_DIR/db
DAEMON_URL=$DAEMON_URL
COIN=$COIN
NET=$NETWORK
DB_ENGINE=$DB_ENGINE
SERVICES=tcp://0.0.0.0:$PUBLIC_TCP_PORT$( [ -f "/etc/letsencrypt/live/$PUBLIC_HOSTNAME/fullchain.pem" ] && echo ",ssl://0.0.0.0:$PUBLIC_SSL_PORT" )
REPORT_SERVICES=tcp://$PUBLIC_HOSTNAME:$PUBLIC_TCP_PORT$( [ -f "/etc/letsencrypt/live/$PUBLIC_HOSTNAME/fullchain.pem" ] && echo ",ssl://$PUBLIC_HOSTNAME:$PUBLIC_SSL_PORT" )
SSL_CERTFILE=/etc/letsencrypt/live/$PUBLIC_HOSTNAME/fullchain.pem
SSL_KEYFILE=/etc/letsencrypt/live/$PUBLIC_HOSTNAME/privkey.pem
HOST=0.0.0.0
LOG_LEVEL=info
EOF
chmod 640 /etc/electrumx-cac.conf
chown "root:$CAC_GROUP" /etc/electrumx-cac.conf

echo "=== [7/7] Installing systemd service ==="
install -m 644 "$SCRIPT_DIR/electrumx-cac.service" /etc/systemd/system/electrumx-cac.service
sed -i "s|__BUILD_DIR__|$BUILD_DIR|g; s|__USER__|$CAC_USER|g; s|__GROUP__|$CAC_GROUP|g" \
    /etc/systemd/system/electrumx-cac.service
systemctl daemon-reload
systemctl enable electrumx-cac
systemctl restart electrumx-cac

echo ""
echo "Done. journalctl -u electrumx-cac -f to watch initial sync (can take a"
echo "while depending on chain height -- it processes the whole history on"
echo "first run)."
