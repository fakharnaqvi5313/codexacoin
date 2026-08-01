#!/bin/bash
# NO LONGER NEEDED FOR ONGOING SYNC -- P2P sync works correctly once
# codexacoind actually has inbound connection capacity (see
# PARAMETERS.md section 9 item 10: a `maxconnections=8` misconfiguration
# during initial provisioning reserved every slot for outbound and left
# zero for inbound, which looked exactly like a connection-code bug
# until traced with strace). Kept only as an optional fast-bootstrap
# tool: copying blocks/+chainstate/ directly is faster than waiting on
# P2P IBD when spinning up a brand-new node, especially for a small
# chain. Not automated via cron -- a real node should just stay synced
# via normal P2P.
#
# Usage: run on the explorer's node host, with SSH access configured to
# a source node that has the current chain:
#   CAC_SOURCE_SSH=user@source-host CAC_SOURCE_DATADIR=/path/to/datadir \
#     ./cac-resync.sh
set -euo pipefail
systemctl stop codexacoind
rsync -a --delete "${CAC_SOURCE_SSH:?set CAC_SOURCE_SSH}:${CAC_SOURCE_DATADIR:?set CAC_SOURCE_DATADIR}/blocks/" /var/lib/codexacoind/blocks/
rsync -a --delete "${CAC_SOURCE_SSH}:${CAC_SOURCE_DATADIR}/chainstate/" /var/lib/codexacoind/chainstate/
chown -R codexacoin:codexacoin /var/lib/codexacoind
systemctl start codexacoind
