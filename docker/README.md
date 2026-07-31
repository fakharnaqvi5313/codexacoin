# CodexaCoin 3-node regtest Docker environment

Brings up three independent `codexacoind` regtest nodes on a private Docker
network, connected to each other, and a one-shot `init` service that mines
the premine window, verifies supply/PoW-rejection/staking-propagation, and
exits.

This is the Docker Compose deliverable referenced in the project spec's
Phase 2 ("Bring up a 3-node regtest network in Docker Compose: mine/mint the
premine, send transactions, verify staking activates, verify PoS-only
enforcement"). The same behavior is also covered without Docker by
`codexacoin-core/test/functional/feature_premine.py`,
`feature_coinage_reward.py`, and `feature_pos_reorg.py` — those ran and
passed against the actual compiled binary this session; **this Docker setup
has not itself been executed** (no Docker runtime is installed in the
environment this was authored in — installing Docker Desktop requires GUI
interaction this agent session couldn't drive). Treat it as reviewed,
consistent-with-the-real-build config, not as independently verified.

## Usage

```bash
# From the docker/ directory (or pass -f docker/docker-compose.yml from the repo root)
docker compose up -d node0 node1 node2

# Give the nodes a few seconds to find each other over -addnode, then:
docker compose run --rm init

# Watch a node directly:
docker compose logs -f node0

# Manual RPC from the host (node0's RPC port is published):
docker exec -it docker-node0-1 codexacoin-cli -regtest -rpcuser=cacdevRPC -rpcpassword=cacdevRPCpass getblockchaininfo

# Tear down and wipe all chain state:
docker compose down -v
```

## What `init` actually checks

1. Mines the 500-block premine window on node0.
2. Sums every premine block's coinbase output (reusing
   `../codexacoin-core/scripts/audit_premine_supply.py` unmodified) and
   asserts the total is exactly 14,000,000,000 CAC.
3. Attempts a PoW block at height 501 and asserts it's rejected
   (`reject-pow`) — proves PoS-only enforcement past the premine window.
4. Waits for node1/node2 to sync to node0's tip.
5. Waits for the built-in staking thread to produce a PoS block past the
   window. **This step can take several minutes** — see PARAMETERS.md
   section 6.2: rapidly mining 500 blocks pushes the chain's
   median-time-past minutes ahead of real wall-clock time, and PoS blocks
   are correctly withheld until real time catches up. This is expected
   behavior, not a hang.
6. Waits for the staked block to propagate to node1/node2.

## Notes on the images

- `docker/Dockerfile` has three targets: `builder` (compiles from the
  `codexacoin-core/` source tree via the Docker Compose build context —
  whatever's in the working tree, not a fresh clone), `runtime` (the actual
  node image — `codexacoind`/`codexacoin-cli` only, no Qt, no Boost runtime
  dependency — confirmed via `otool -L` on the macOS build this session
  that Boost is header-only here), and `init` (adds `python3` so the
  one-shot service can reuse the real audit script instead of
  reimplementing JSON parsing in POSIX shell).
- RPC credentials (`cacdevRPC` / `cacdevRPCpass`) are fixed, throwaway,
  regtest-only development credentials set directly in
  `docker-compose.yml` so the `init` container — which doesn't share any
  node's private data volume — can authenticate without cookie-file
  volume-sharing gymnastics. **Never reuse these for testnet or mainnet.**
- Each node gets its own named Docker volume (`node0-data` etc.) so chain
  state survives container restarts within a `docker compose up` session;
  `docker compose down -v` wipes it.
