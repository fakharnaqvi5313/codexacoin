#!/bin/sh
# CodexaCoin Docker Compose 3-node regtest init.
#
# Mines the premine window on node0, verifies the total is exactly
# 14,000,000,000 CAC (reusing codexacoin-core/scripts/audit_premine_supply.py
# unmodified, mounted read-only at /audit -- this container carries python3
# specifically so that script doesn't need reimplementing in shell),
# confirms PoW is rejected past the window, waits for node1/node2 to sync
# to the same tip, then confirms staking produces at least one PoS block
# that also propagates network-wide.
#
# Run with: docker compose run --rm init

set -eu

RPC_USER="${RPC_USER:?RPC_USER not set}"
RPC_PASS="${RPC_PASS:?RPC_PASS not set}"

CLI0="codexacoin-cli -regtest -rpcconnect=node0 -rpcport=36211 -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS"
CLI1="codexacoin-cli -regtest -rpcconnect=node1 -rpcport=36211 -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS"
CLI2="codexacoin-cli -regtest -rpcconnect=node2 -rpcport=36211 -rpcuser=$RPC_USER -rpcpassword=$RPC_PASS"

PREMINE_WINDOW=500

wait_for_rpc() {
    label="$1"; shift
    echo "Waiting for $label RPC..."
    tries=0
    until $* getblockcount >/dev/null 2>&1; do
        tries=$((tries + 1))
        if [ "$tries" -gt 60 ]; then
            echo "FAIL: $label RPC never came up" >&2
            exit 1
        fi
        sleep 2
    done
    echo "$label is up."
}

wait_for_tips_match() {
    label="$1"
    max_tries="$2"
    tip0=$($CLI0 getbestblockhash)
    tries=0
    while [ "$($CLI1 getbestblockhash)" != "$tip0" ] || [ "$($CLI2 getbestblockhash)" != "$tip0" ]; do
        tries=$((tries + 1))
        if [ "$tries" -gt "$max_tries" ]; then
            echo "FAIL: node1/node2 never synced to node0's tip ($label)" >&2
            exit 1
        fi
        sleep 2
        tip0=$($CLI0 getbestblockhash)
    done
    echo "PASS: all three nodes agree on the tip ($tip0) [$label]."
}

wait_for_rpc node0 $CLI0
wait_for_rpc node1 $CLI1
wait_for_rpc node2 $CLI2

echo "Creating wallet on node0..."
$CLI0 createwallet founder >/dev/null 2>&1 || echo "(wallet already exists, continuing)"
ADDR=$($CLI0 getnewaddress)
echo "Founder address: $ADDR"

echo "Mining the ${PREMINE_WINDOW}-block premine window on node0..."
$CLI0 generatetoaddress "$PREMINE_WINDOW" "$ADDR" >/dev/null

echo "Verifying premine total via audit_premine_supply.py..."
python3 /audit/audit_premine_supply.py \
    --rpcconnect=node0 --rpcport=36211 \
    --rpcuser="$RPC_USER" --rpcpassword="$RPC_PASS" \
    --last-pow-block="$PREMINE_WINDOW"

echo "Confirming PoW is rejected past the premine window (block $((PREMINE_WINDOW + 1)))..."
if $CLI0 generatetoaddress 1 "$ADDR" >/dev/null 2>&1; then
    echo "FAIL: PoW block was accepted past the premine window" >&2
    exit 1
fi
echo "PASS: PoW correctly rejected."

wait_for_tips_match "post-premine" 60

# See PARAMETERS.md section 6.2: after a rapid bulk-mine of the premine
# window, the chain's median-time-past runs ahead of real wall-clock time,
# and PoS blocks are correctly withheld until real time catches up. This
# is expected -- not a hang -- and can take several minutes.
echo "Waiting for staking to produce a block past the premine window (this can take several minutes, see PARAMETERS.md section 6.2)..."
tries=0
while [ "$($CLI0 getblockcount)" -le "$PREMINE_WINDOW" ]; do
    tries=$((tries + 1))
    if [ "$tries" -gt 180 ]; then
        echo "FAIL: no PoS block produced after 15 minutes" >&2
        exit 1
    fi
    sleep 5
done
stake_height=$($CLI0 getblockcount)
echo "PASS: staked block at height $stake_height."

echo "Waiting for the staked block to propagate to node1/node2..."
wait_for_tips_match "post-stake" 60

echo ""
echo "=== 3-node regtest network verified: premine exact, PoW rejected post-window, PoS staking propagates ==="
