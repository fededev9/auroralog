FROM elixir:1.19.5 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    rustc \
    cargo \
    && rm -rf /var/lib/apt/lists/*

ENV MIX_ENV=prod
WORKDIR /app

# Prime cache layers for Mix and Rust dependencies.
COPY mix.exs mix.lock ./
COPY config ./config
COPY apps/aura_log/mix.exs apps/aura_log/mix.exs
COPY apps/aura_log_web/mix.exs apps/aura_log_web/mix.exs
COPY native/auralog_core/Cargo.toml native/auralog_core/Cargo.toml
COPY native/auralog_core/src native/auralog_core/src

RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get

# Copy the rest of the source and build once.
COPY . .
RUN mix deps.get && mix duckdb_ex.install
RUN cd apps/aura_log_web && mix assets.deploy && cd /app && mix compile && mix release auralog

FROM debian:trixie-slim AS app_runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl \
    libstdc++6 \
    libgcc-s1 \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/auralog /app/auralog

# duckdb_ex runs the DuckDB CLI (erlexec); expose it on PATH for the release.
RUN DDB="$(find /app/auralog -type f -path '*/priv/duckdb/duckdb' 2>/dev/null | head -n1)" && \
    if [ -n "${DDB}" ]; then ln -sf "${DDB}" /usr/local/bin/duckdb; fi

# Secrets (SECRET_KEY_BASE, AURALOG_INGEST_JWT_SECRET) must be supplied at runtime
# via compose, Kubernetes, or your orchestrator — do not bake them into the image.
ENV PHX_SERVER=true \
    PORT=4000 \
    AURALOG_DUCKDB_PATH=/data/auralog.duckdb

EXPOSE 4000 9000/udp
CMD ["/app/auralog/bin/auralog", "start"]
