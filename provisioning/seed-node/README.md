# CodexaCoin testnet seed node provisioning

Shell-based provisioning (per the project spec: "provide Ansible or shell
provisioning scripts" — shell chosen for zero additional tooling
dependency; an Ansible playbook wrapping the same steps would be a
straightforward follow-up if the project standardizes on Ansible for
broader fleet management later).

## What a seed node is (and isn't)

A seed node is a **pure P2P relay and full-validating node** — it syncs
the chain, relays blocks/transactions to peers, and shows up as a peer
other nodes can bootstrap from. It holds **no wallet, no premine, no
keys**. See PARAMETERS.md's discussion of how VPS deployment actually
works: the premine only ever exists on whichever machine actually mines
the 500-block founder window; seed nodes just sync a copy of the resulting
chain like any other node.

`provision.sh` builds `codexacoind` with `--disable-wallet` specifically
so this is enforced at the binary level, not just by convention.

## Usage

On a fresh Ubuntu 22.04/24.04 or Debian 12 VPS, as root:

```bash
git clone <this-repo-or-just-copy-this-directory> /tmp/cac-provision
cd /tmp/cac-provision/provisioning/seed-node
REPO_URL=https://github.com/codexacoin/codexacoin-core.git REPO_REF=master ./provision.sh
```

(`REPO_URL`/`REPO_REF` default to the placeholder values above — override
them once the project has settled on its real public remote.)

This installs build dependencies, compiles `codexacoind` from source,
installs it as a systemd service (`codexacoind.service`, reusing
`codexacoin-core/contrib/init/codexacoind.service` unmodified), opens only
the testnet P2P port (26210) via `ufw`, and starts the service.

Re-running `provision.sh` is safe — it pulls the latest `REPO_REF`,
rebuilds, and restarts the service, without touching an existing
`/etc/codexacoin/codexacoin.conf` you may have hand-edited.

## After provisioning both seed nodes

Edit `/etc/codexacoin/codexacoin.conf` on each to `addnode=` the other's
IP/hostname (commented placeholder already in
`codexacoin.conf.testnet`), then `systemctl restart codexacoind`.

Once real seed hostnames exist, update the `vSeeds` placeholders in
`codexacoin-core/src/kernel/chainparams.cpp`'s `CTestNetParams`
(`testnet-seed1.codexacoin.example` / `testnet-seed2.codexacoin.example`
are TODO placeholders — see PARAMETERS.md section 9) and rebuild.

## Verifying

```bash
sudo -u codexacoin codexacoin-cli -testnet \
    -conf=/etc/codexacoin/codexacoin.conf -datadir=/var/lib/codexacoind \
    getblockchaininfo

journalctl -u codexacoind -f
```

## Not covered here (deliberately out of scope for a seed node)

- Mining the real testnet premine window (a one-time ceremony on a
  separate, trusted machine — see PARAMETERS.md section 9).
- Checkpointing the premine block hashes into `chainparams.cpp` afterward.
- Anything wallet- or faucet-related — see `../faucet/` for that, which is
  an explicitly separate, funded-after-the-fact service, not a seed node
  responsibility.
