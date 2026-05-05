# AuraLog

AuraLog is a self-hosted, open-source real-time log analytics platform built with Elixir/Phoenix, LiveView, Rust (Rustler), and DuckDB.

## Stack

- Elixir + Phoenix for orchestration, ingestion, and web delivery
- Phoenix LiveView for zero-JavaScript realtime dashboard updates
- Rust + Rustler NIFs for high-throughput log parsing and tokenization
- DuckDB for OLAP-grade on-disk analytics

## Monorepo layout

- `apps/aura_log`: ingestion, parsing orchestration, storage, and query services
- `apps/aura_log_web`: Phoenix/LiveView dashboard and API
- `native/auralog_core`: Rust parsers and compute-heavy functions
- `infra/docker`: Docker compose and runtime container assets
- `docs`: architecture and operational documentation

## Quickstart (Docker)

```bash
docker compose -f infra/docker/docker-compose.yml --profile demo up --build
```

HTTP ingest endpoint: `http://localhost:4000/api/ingest`  
Dashboard: `http://localhost:4000/dashboard`

The `seed_ingest` service runs only in `demo` profile and generates fake logs.

## Production startup (no mock data)

Required secrets:

- `SECRET_KEY_BASE`
- `AURALOG_INGEST_JWT_SECRET`

Run:

```bash
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
export AURALOG_INGEST_JWT_SECRET="replace-with-strong-secret"
docker compose -f infra/docker/docker-compose.prod.yml up --build -d
```

## Local Phoenix workflow (Phoenix LiveView standard)

From the repository root:

```bash
mix deps.get
cd apps/aura_log_web
mix assets.setup
mix assets.build
cd ../..
mix compile
mix phx.server
```

Release assets (used by Docker build):

```bash
cd apps/aura_log_web
mix assets.deploy
```

## Quick smoke checks

- Root redirect: `http://localhost:4000/` -> `/dashboard`
- Dashboard: `http://localhost:4000/dashboard`
- Search URL-driven: `http://localhost:4000/dashboard?q=api`
- Styled error page example: `http://localhost:4000/dashbo`
- Health endpoint: `http://localhost:4000/health`

## JWT ingest contract

`POST /api/ingest` now requires `Authorization: Bearer <jwt>` using `HS256`.

Minimum claims:

- `sub` (subject)
- `tenant` (tenant id)
- `exp` (expiry)

Example payload:

```json
{
  "raw": "127.0.0.1 - - [10/Oct/2000:13:55:36 -0700] \"GET /api/items HTTP/1.1\" 200 123"
}
```

The server always derives tenant from JWT claims (not from request body).

## Operations

- Backup: `infra/docker/backup_duckdb.sh`
- Restore: `infra/docker/restore_duckdb.sh <file.duckdb>`
- Retention prune: `infra/docker/prune_backups.sh`
- Post-deploy smoke: `infra/docker/smoke_post_deploy.sh`

## Kubernetes baseline

Baseline manifests are in `infra/k8s/`:

- namespace, configmap, secret example
- pvc, deployment, service
- hpa, pdb, network policy
