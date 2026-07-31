# CodexaCoin regtest node image.
#
# Multi-stage build: compiles codexacoind from source in a Debian builder
# stage (matching the dependency list in codexacoin-core/doc/build-unix.md,
# the same deps used to build this project successfully on macOS this
# session -- just the Debian/apt package names instead of Homebrew's),
# then copies only the resulting binaries + runtime libs into a slim
# runtime image. Headless daemon only (no Qt) -- matches Phase 1's
# codexacoind build (SQLite wallet, no Berkeley DB).

FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libtool \
    autotools-dev \
    automake \
    pkg-config \
    bsdmainutils \
    python3 \
    libevent-dev \
    libboost-dev \
    libsqlite3-dev \
    ca-certificates \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
# Built from the repo checkout on the host (see docker-compose.yml build
# context: ../codexacoin-core), not cloned fresh -- this bakes in whatever
# consensus/parameter state the working tree is actually at.
COPY codexacoin-core/ /build/

RUN ./autogen.sh && \
    ./configure --without-gui --disable-bench --disable-tests --disable-fuzz-binary \
                --with-sqlite=yes --without-bdb --disable-hardening && \
    make -j"$(nproc)"

FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    libevent-2.1-7 \
    libevent-pthreads-2.1-7 \
    libsqlite3-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash codexacoin

# No libboost-* runtime package: confirmed via `otool -L` on the macOS build
# this session that codexacoind has zero dynamic Boost dependency (this
# codebase only uses Boost's header-only components). libtool/ldd would
# confirm the same on Linux; if a future dependency bump changes that,
# `ldd /usr/local/bin/codexacoind` in this stage will immediately show it.

COPY --from=builder /build/src/codexacoind /usr/local/bin/codexacoind
COPY --from=builder /build/src/codexacoin-cli /usr/local/bin/codexacoin-cli

USER codexacoin
WORKDIR /home/codexacoin
VOLUME ["/home/codexacoin/.codexacoin"]

EXPOSE 36210 36211

ENTRYPOINT ["codexacoind"]
CMD ["-regtest", "-printtoconsole", "-rpcallowip=0.0.0.0/0", "-rpcbind=0.0.0.0"]

# Separate target for docker-compose.yml's `init` service only -- adds
# python3 (needed to reuse ../codexacoin-core/scripts/audit_premine_supply.py
# unmodified rather than re-implementing JSON parsing in POSIX shell) and
# runs as root so it can wait_for/curl freely; never used for the actual
# node containers.
FROM debian:bookworm-slim AS init

RUN apt-get update && apt-get install -y --no-install-recommends \
    libevent-2.1-7 \
    libevent-pthreads-2.1-7 \
    libsqlite3-0 \
    python3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/src/codexacoin-cli /usr/local/bin/codexacoin-cli
WORKDIR /work
