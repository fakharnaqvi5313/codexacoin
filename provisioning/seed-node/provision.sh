#!/bin/bash
# CodexaCoin testnet seed node provisioning script.
#
# Target: fresh Ubuntu 22.04/24.04 or Debian 12 VPS. Idempotent -- safe to
# re-run (skips steps already done, restarts the service to pick up any
# config/binary changes).
#
# What this does NOT do: mine any premine, hold any wallet keys, or run
# anything resembling a hot wallet. A seed node is pure P2P relay +
# validation -- see PARAMETERS.md's "How VPS deployment actually works"
# discussion for why premine/wallet concerns are deliberately out of scope
# here. This script explicitly disables the wallet.
#
# Usage (as root or via sudo):
#   REPO_URL=https://github.com/codexacoin/codexacoin-core.git \
#   REPO_REF=master \
#   ./provision.sh
#
# Override REPO_URL/REPO_REF to point at a specific fork/branch/tag once
# the real project has a public remote; defaults below are placeholders
# consistent with PARAMETERS.md's placeholder org.

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/codexacoin/codexacoin-core.git}"
REPO_REF="${REPO_REF:-master}"
CAC_USER="codexacoin"
CAC_GROUP="codexacoin"
BUILD_DIR="/opt/codexacoin-build"
CONF_DIR="/etc/codexacoin"
DATA_DIR="/var/lib/codexacoind"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root (or with sudo)." >&2
    exit 1
fi

echo "=== [1/7] Installing build dependencies ==="
apt-get update
apt-get install -y --no-install-recommends \
    build-essential libtool autotools-dev automake pkg-config bsdmainutils \
    python3 libevent-dev libboost-dev libsqlite3-dev ca-certificates git \
    ufw

echo "=== [2/7] Creating service user/group ==="
if ! getent group "$CAC_GROUP" >/dev/null; then
    groupadd --system "$CAC_GROUP"
fi
if ! getent passwd "$CAC_USER" >/dev/null; then
    useradd --system --gid "$CAC_GROUP" --home-dir "$DATA_DIR" \
        --shell /usr/sbin/nologin --comment "CodexaCoin seed node" "$CAC_USER"
fi

echo "=== [3/7] Fetching + building codexacoind (this takes a while) ==="
mkdir -p "$BUILD_DIR"
if [ ! -d "$BUILD_DIR/.git" ]; then
    git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$BUILD_DIR"
else
    git -C "$BUILD_DIR" fetch --depth 1 origin "$REPO_REF"
    git -C "$BUILD_DIR" checkout "$REPO_REF"
    git -C "$BUILD_DIR" reset --hard "origin/$REPO_REF"
fi

cd "$BUILD_DIR"
./autogen.sh
./configure \
    --without-gui \
    --disable-wallet \
    --disable-bench \
    --disable-tests \
    --disable-fuzz-binary \
    --disable-hardening
make -j"$(nproc)"

echo "=== [4/7] Installing binaries ==="
install -m 0755 -o root -g root src/codexacoind /usr/bin/codexacoind
install -m 0755 -o root -g root src/codexacoin-cli /usr/bin/codexacoin-cli

echo "=== [5/7] Writing config ==="
mkdir -p "$CONF_DIR"
if [ ! -f "$CONF_DIR/codexacoin.conf" ]; then
    install -m 0640 -o root -g "$CAC_GROUP" "$SCRIPT_DIR/codexacoin.conf.testnet" "$CONF_DIR/codexacoin.conf"
    echo "Wrote default testnet seed config to $CONF_DIR/codexacoin.conf"
else
    echo "$CONF_DIR/codexacoin.conf already exists, not overwriting (edit manually if needed)"
fi
chgrp "$CAC_GROUP" "$CONF_DIR"

mkdir -p "$DATA_DIR"
chown "$CAC_USER:$CAC_GROUP" "$DATA_DIR"
chmod 0710 "$DATA_DIR"

echo "=== [6/7] Installing systemd service ==="
# Reuses the project's own unit file rather than duplicating it -- keeps
# this script from drifting out of sync with codexacoin-core's own
# packaging as it evolves.
install -m 0644 "$BUILD_DIR/contrib/init/codexacoind.service" \
    /etc/systemd/system/codexacoind.service
systemctl daemon-reload
systemctl enable codexacoind.service
systemctl restart codexacoind.service

echo "=== [7/7] Firewall: P2P port only ==="
# CodexaCoin testnet P2P port (PARAMETERS.md section 3.2). RPC (26211) is
# intentionally NOT opened -- a seed node has no reason to expose RPC to
# the internet; operators needing remote RPC should use an SSH tunnel.
ufw allow 26210/tcp comment "CodexaCoin testnet P2P"
ufw --force enable

echo ""
echo "=== Done. Status: ==="
systemctl status codexacoind.service --no-pager -l || true
echo ""
echo "Follow logs with: journalctl -u codexacoind -f"
echo "Check sync status with: sudo -u $CAC_USER codexacoin-cli -testnet -conf=$CONF_DIR/codexacoin.conf -datadir=$DATA_DIR getblockchaininfo"
