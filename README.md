# AuraLog

[![CI](https://github.com/fededev9/auroralog/actions/workflows/ci.yml/badge.svg)](https://github.com/fededev9/auroralog/actions/workflows/ci.yml)

AuraLog is a self-hosted, open-source (Apache-2.0) real-time log analytics platform built with Elixir/Phoenix, LiveView, Rust (Rustler), and DuckDB.

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

HTTP ingest: `http://localhost:4000/api/ingest`  
Dashboard: `http://localhost:4000/dashboard`

The `seed_ingest` service runs only in the `demo` profile and generates sample logs. You should see charts within about two minutes. See [docs/time_to_first_graph.md](docs/time_to_first_graph.md).

## Production startup

Copy [.env.example](.env.example) and set secrets at runtime (the image does not embed them):

- `SECRET_KEY_BASE` — `mix phx.gen.secret`
- `AURALOG_INGEST_JWT_SECRET` — long random string for ingest JWT validation

```bash
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
export AURALOG_INGEST_JWT_SECRET="replace-with-strong-secret"
docker compose -f infra/docker/docker-compose.prod.yml up --build -d
./infra/docker/smoke_post_deploy.sh
```

UDP ingest is **disabled by default** in production. The prod compose file does not publish UDP port `9000`.

## Local development

```bash
mix deps.get
chmod +x infra/scripts/install_duckdb_cli.sh
./infra/scripts/install_duckdb_cli.sh priv/duckdb
cd apps/aura_log_web && mix assets.setup && mix assets.build && cd ../..
mix compile
mix phx.server
```

## JWT ingest contract

`POST /api/ingest` requires `Authorization: Bearer <jwt>` (HS256).

Claims:

- `sub` (subject)
- `tenant` (tenant id; enforced server-side, not from body)
- `exp` (expiry)

Body example:

```json
{
  "raw": "127.0.0.1 - - [10/Oct/2000:13:55:36 -0700] \"GET /api/items HTTP/1.1\" 200 123"
}
```

## Search and storage (v1.0)

- Logs persist to DuckDB table `logs`.
- Search uses token index table `log_terms` (Rust tokenization).
- Dashboard throughput/errors prefer minute rollup table `logs_1m`, with fallback to raw `logs` when empty.

## UDP ingest (optional)

Production: set `AURALOG_UDP_INGEST_ENABLED=true` **and** `AURALOG_UDP_INGEST_TOKEN` only on trusted networks.

JSON datagram format:

```json
{"token":"<secret>","tenant":"<tenant>","raw":"<log line>"}
```

Local `mix phx.server` enables UDP by default unless `AURALOG_UDP_INGEST_ENABLED=false`.

## Integrations

OpenTelemetry Collector and Vector examples: [docs/integrations.md](docs/integrations.md).

## Operations

- Backup: `infra/docker/backup_duckdb.sh`
- Restore: `infra/docker/restore_duckdb.sh <file.duckdb>`
- Retention prune: `infra/docker/prune_backups.sh`
- Runbook: [docs/operations_runbook.md](docs/operations_runbook.md)

## Kubernetes

Baseline manifests: `infra/k8s/`.

## Security

See [SECURITY.md](SECURITY.md).

## Not yet supported (post-v1 roadmap)

- Full OpenTelemetry / OTLP native receiver
- Metrics, traces, and APM
- Multi-node HA and object-storage backends
- SSO, RBAC, and multi-tenant admin UI
- Alerting and notification channels

## License

Apache License 2.0 — see [LICENSE](LICENSE).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
