# AuraLog Operations Runbook

## SLO targets

- RPO: <= 15 minutes (schedule backup at least every 15 minutes)
- RTO: <= 30 minutes (restore + service restart + smoke validation)

## Prerequisites

- Production stack started with `infra/docker/docker-compose.prod.yml`
- `SECRET_KEY_BASE` and `AURALOG_INGEST_JWT_SECRET` set
- Backup storage mounted or synced off-host

## Backup procedure

```bash
COMPOSE_FILE=infra/docker/docker-compose.prod.yml ./infra/docker/backup_duckdb.sh
```

Output file is written under `infra/docker/backups/`.

## Restore procedure

```bash
COMPOSE_FILE=infra/docker/docker-compose.prod.yml ./infra/docker/restore_duckdb.sh infra/docker/backups/auralog-<stamp>.duckdb
```

## Retention policy

Default retention keeps 14 days of backups:

```bash
RETENTION_DAYS=14 ./infra/docker/prune_backups.sh
```

## Post-restore validation

```bash
export AURALOG_INGEST_JWT_SECRET="<same-prod-secret>"
./infra/docker/smoke_post_deploy.sh
```

Checks performed:

1. `GET /health`
2. JWT-authenticated `POST /api/ingest`
3. Dashboard search reachability

## Security controls

- Ingest API requires JWT (HS256)
- Tenant is derived from JWT claim `tenant`
- Basic fixed-window rate limit per tenant/token/ip
- Ingest payload size limit is enforced by `Plug.Parsers` (HTTP ingest scope and Phoenix endpoint)
- UDP ingest is disabled by default in production (`AURALOG_UDP_INGEST_ENABLED`); enable only on trusted networks

## Known operational limits

- DuckDB embedded model is single-writer oriented.
- Horizontal scaling on multiple writers requires external coordination/storage strategy.
