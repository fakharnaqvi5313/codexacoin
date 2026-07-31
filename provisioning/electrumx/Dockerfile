# CodexaCoin Electrum server (electrumx-cac) image.
#
# Uses Debian's packaged libleveldb-dev rather than a from-source Homebrew
# build -- sidesteps the exact plyvel/leveldb ABI mismatch hit when
# developing this locally on macOS 12 (ldb symbol visibility differences
# between Homebrew's leveldb build and plyvel's compiled expectations; see
# PARAMETERS.md section 9 / CHANGELOG.md Phase 4 for the full writeup).
# This Debian-packaged path is the standard, well-trodden one for
# electrumx/plyvel and does not have that problem.

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-venv \
    python3-dev \
    build-essential \
    libleveldb-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash electrumx

WORKDIR /build
# Built from the repo checkout on the host (see the sibling
# docker-compose.yml, if used, for the build context), not cloned fresh --
# bakes in whatever coin-definition state the working tree is actually at.
COPY . /build/

RUN python3 -m venv /build/venv && \
    /build/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /build/venv/bin/pip install --no-cache-dir -e "/build[leveldb]"

USER electrumx
WORKDIR /home/electrumx
VOLUME ["/home/electrumx/db"]

# tcp + ssl service ports (mainnet defaults; override via SERVICES env var
# for testnet/regtest -- see provision.sh's port table)
EXPOSE 50001 50002

ENV DB_DIRECTORY=/home/electrumx/db
ENV DB_ENGINE=leveldb
ENV COIN=CodexaCoin
ENV NET=mainnet
ENV SERVICES=tcp://0.0.0.0:50001
ENV PEER_DISCOVERY=off
ENV PEER_ANNOUNCE=false

ENTRYPOINT ["/build/venv/bin/python3", "/build/electrumx_server"]
