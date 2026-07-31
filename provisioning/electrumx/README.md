# CodexaCoin Electrum server provisioning (electrumx-cac)

Adapts [CoinBlack/electrumx-blk](https://github.com/CoinBlack/electrumx-blk)
(Blackcoin's own ElectrumX fork) to CAC, the same way `codexacoin-core`
adapts `blackcoin-more` — see `../../electrumx-cac/` at the CodexaCloud repo
root for the actual source. This directory is deployment tooling only.

## Why ElectrumX, not Fulcrum

The spec named either as acceptable ("Adapt ElectrumX (or Fulcrum) to
CAC"). Fulcrum has no generic altcoin support — it's built specifically for
BTC/BCH/LTC's transaction formats, with no PoS/coinstake handling.
`electrumx-blk` already ships a Blackcoin-specific transaction deserializer
(`DeserializerBlackcoinSegWit`) that correctly parses the PoS coinstake
`nTime` field CAC inherits unchanged, and a version-conditional
scrypt/SHA256d header-hash mixin that already matches this fork's actual
block-version behavior (every real CAC block is `nVersion=7`, confirmed in
Phase 1) with zero logic changes needed. Adapting it was almost entirely
chain-identity configuration (genesis hash, RPC port, address prefixes),
not protocol work — see the `CodexaCoin`/`CodexaCoinTestnet`/
`CodexaCoinRegtest` classes added to `electrumx-cac/src/electrumx/lib/coins.py`.

## What was actually verified this phase

Ran a local regtest `codexacoind`, pointed `electrumx-cac` at its RPC with
`COIN=CodexaCoinRegtest`, and confirmed it **successfully connected and
identified the daemon** (`BlackcoinDaemon:daemon #1 at 127.0.0.1:36211/
(current)` in its own log) — proving the coin definition (RPC port, daemon
class) is correct.

Full end-to-end indexing (`DB` layer actually syncing blocks) was **not**
verified locally: both of electrumx's supported storage backends failed to
build/run on this development machine specifically because of its macOS
version (12.7.6 — below Homebrew's supported tier for the `rocksdb`
formula; separately, the `leveldb` Python binding, `plyvel`, built but hit
a runtime symbol-visibility mismatch against Homebrew's `leveldb` library).
Neither is a CAC-adaptation problem — they're environment packaging issues
specific to this old macOS version. The `Dockerfile` in this directory
sidesteps them entirely by using Debian's packaged `libleveldb-dev` (the
standard, well-trodden path for electrumx/plyvel), and should be the
preferred way to actually run this, including in production.

## Usage

### Docker (recommended, avoids the macOS packaging issue above)

```bash
cd electrumx-cac
docker build -f ../provisioning/electrumx/Dockerfile -t electrumx-cac .
docker run -d --name electrumx-cac \
  -e DAEMON_URL="http://rpcuser:rpcpassword@<node-host>:16211/" \
  -e COIN=CodexaCoin -e NET=mainnet \
  -p 50001:50001 -p 50002:50002 \
  -v electrumx-cac-db:/home/electrumx/db \
  electrumx-cac
```

### Bare VPS (systemd)

On a fresh Ubuntu 22.04/24.04 or Debian 12 VPS, with a fully-synced,
`-txindex`-enabled `codexacoind` already reachable:

```bash
REPO_URL=https://github.com/codexacoin/electrumx-cac.git \
REPO_REF=master \
PUBLIC_HOSTNAME=electrum1.codexacoin.example \
NETWORK=testnet \
DAEMON_URL="http://rpcuser:rpcpassword@127.0.0.1:26211/" \
sudo -E ./provision.sh
```

This installs `libleveldb-dev` + build tools, clones and `pip install -e`s
`electrumx-cac` into a venv, obtains a Let's Encrypt cert via `certbot`
(standalone mode — needs DNS for `PUBLIC_HOSTNAME` already pointed at this
host, or it warns and continues without TLS so you can rerun later),
writes `/etc/electrumx-cac.conf`, and installs+starts the
`electrumx-cac.service` systemd unit. electrumx has native TLS support
(`SSL_CERTFILE`/`SSL_KEYFILE`) — no nginx/stunnel reverse-proxy needed.

Re-running `provision.sh` is safe (idempotent).

## For the second server

Repeat with a different `PUBLIC_HOSTNAME` (spec asks for 2 Electrum
servers). They don't need to talk to each other — each independently
indexes from its own (or a shared) `codexacoind`'s RPC.

## Verifying

```bash
journalctl -u electrumx-cac -f   # watch initial sync

# from any machine, once a cert is live:
echo '{"id": 1, "method": "blockchain.headers.subscribe", "params": []}' | \
  openssl s_client -quiet -connect electrum1.codexacoin.example:50002
```

## Ports

| Network | TCP | SSL |
|---|---|---|
| mainnet | 50001 | 50002 |
| testnet | 51001 | 51002 |
| regtest | 52001 | 52002 |

(Deliberately different from Bitcoin's own 50001/50002 mainnet convention
being reused for CAC testnet/regtest, to avoid confusing a wallet pointed
at the wrong network with a plausible-looking but wrong port.)
