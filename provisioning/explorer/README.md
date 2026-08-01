# explorer deployment (real, 2026-08-01)

The block explorer is live at
[codexacoin.com/blockexplorer](https://codexacoin.com/blockexplorer/),
served from the same VPS as [../website/](../website/README.md), under
the same nginx site.

## Architecture on this box

Unlike `../vps-gateway/` (which talks to the same node the Mac already
runs), the explorer needed its own fully-synced, txindex-enabled
`codexacoind` running locally on the VPS — running an explorer against a
node reachable only over the open internet, or worse, exposing the Mac's
wallet-holding node's RPC publicly, was never on the table (see
`../../PARAMETERS.md` section 13.1 for why the explorer is a deliberately
separate, lower-trust service in the first place).

- `codexacoind` (headless, `--without-gui --disable-wallet`, no keys)
  runs as a dedicated `codexacoin` system user, data in
  `/var/lib/codexacoind`, `txindex=1`.
- No Linux binary existed anywhere in this project (only macOS builds
  from earlier phases), so `codexacoind` was built from source directly
  on the VPS (Ubuntu 24.04): `apt-get install` the standard
  Bitcoin-Core-derived build deps (`build-unix.md`), `git archive HEAD |
  ssh ... tar -x` the source over (no GitHub remote exists for this repo
  yet), `./autogen.sh && ./configure --without-gui --disable-wallet
  --disable-tests --disable-bench && make -j$(nproc)`.
- **Found and fixed while doing this**: `src/qt/Makefile`,
  `src/qt/test/Makefile`, and `src/test/Makefile` had never been
  committed to git, going back to the original Phase 1 fork import.
  They're plain, hand-written pass-through Makefiles (not autotools
  templates), and local macOS builds never noticed because they never
  re-run `autoreconf` — they just reuse whatever `Makefile` is already
  sitting in the working tree. A clean checkout hits this immediately.
  Fixed by committing the three files (see the git log entry "Add three
  missing Makefiles that were never tracked by git").
- The explorer app itself (`../../explorer/`) runs as `cac-explorer` via
  gunicorn on `127.0.0.1:8081`, systemd-managed
  (`cac-explorer.service`), same pattern as `explorer.service` in this
  directory.
- nginx serves the static frontend at `/blockexplorer/` (just the
  existing site's default `location /` — `explorer/index.html` uses
  relative asset paths, so nothing special was needed) and reverse-proxies
  `/api/` at the site root to the local gunicorn — `explorer/app.js`'s
  `API_BASE` defaults to same-origin `/api/...`, so this needed no code
  changes at all.

## P2P sync (fixed, was briefly a real config footgun)

This node was initially bootstrapped with a one-time manual copy of
`blocks/`+`chainstate/` from the Mac's node, because P2P connections
between the two appeared completely broken — every attempt vanished with
no trace, looking exactly like a bug in the codebase's connection code.

It wasn't. See `PARAMETERS.md` section 9 item 10 for the full trail
(`-debug=net`, `tcpdump`, `strace` on the live process), but the short
version: this VPS's `codexacoind` had `maxconnections=8` set during
initial provisioning, and Bitcoin Core reserves outbound connection slots
*before* counting inbound capacity — at `maxconnections=8`, the
outbound-full-relay reservation alone (`min(16, 8) = 8`) consumed every
slot, leaving exactly zero for inbound. Every connection attempt was
silently dropped as "full," and the log line that would have explained
why was itself gated behind a debug category that wasn't enabled. Fixed
by removing the `maxconnections` override — don't set it below roughly
20 on a node that needs to accept inbound connections, or do the same
slot math first if you must.

Real P2P sync works correctly now, verified both directions
(`getpeerinfo` shows each node as a peer of the other). `cac-resync.sh`
in this directory is no longer needed for ongoing sync — kept only as an
optional fast-bootstrap tool for spinning up a brand-new node without
waiting on P2P from scratch.

## Verified

`https://codexacoin.com/api/stats` and `.../blockexplorer/` both serve
real chain data (height 521 at deployment time). `../#/block/1` in the
explorer UI showed the exact same block-1 hash
(`25efc90ff657ec53e25352ab523c583b37ec100a31b1c88bbb8961b2e074654d`)
that's hardcoded in mainnet's `checkpointData`, with the correct
28,000,000 CAC coinbase output.
