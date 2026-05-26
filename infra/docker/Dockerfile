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
# duckdb_ex.install starts the app; use dev env so prod runtime.exs secrets are not required at build time.
RUN MIX_ENV=dev AURALOG_DUCKDB_PATH=/app/priv/data/auralog.duckdb mix duckdb_ex.install
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
COPY --from=builder /app/priv/duckdb /app/priv/duckdb

# duckdb_ex runs the DuckDB CLI (erlexec); expose it on PATH for the release.
RUN ln -sf /app/priv/duckdb/duckdb /usr/local/bin/duckdb

# Secrets (SECRET_KEY_BASE, AURALOG_INGEST_JWT_SECRET) must be supplied at runtime
# via compose, Kubernetes, or your orchestrator — do not bake them into the image.
ENV PHX_SERVER=true \
    PORT=4000 \
    AURALOG_DUCKDB_PATH=/data/auralog.duckdb \
    DUCKDB_PATH=/app/priv/duckdb/duckdb

EXPOSE 4000 9000/udp
CMD ["/app/auralog/bin/auralog", "start"]
