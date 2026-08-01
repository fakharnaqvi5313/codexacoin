#!/bin/bash
# TEMPORARY stopgap: codexacoind's outbound addnode/P2P connection
# machinery isn't actually attempting connections (confirmed: OS-level
# networking is fine -- raw socket connects instantly -- but neither
# `addnode ... onetry` nor a config-level addnode= ever produces a
# connection attempt in debug.log, on either side of the connection).
# That's a real bug in this codebase's connection-management code, not
# specific to this deployment -- see PARAMETERS.md section 9 item 10.
# Until it's fixed, this VPS node can't sync via real P2P, so this
# script periodically re-copies blocks/chainstate from a source node
# that does have the current chain instead. Remove this once P2P sync
# actually works -- it is a workaround, not the intended design (see
# ../../PARAMETERS.md section 13.1 for the intended trust-boundary
# reasoning, which assumes a real P2P-synced node).
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
