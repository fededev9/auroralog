# Changelog

All notable changes to this project are documented in this file.

## [1.0.0] - 2026-05-26

### Added

- Term-based search via DuckDB `log_terms` table (Rust tokenization).
- Minute rollup table `logs_1m` for throughput and error KPIs.
- Shared DuckDB connection for writes and reads (`DuckDBWriter` + `Query.Service`).
- UDP ingest JSON auth: `{"token","tenant","raw"}` when `AURALOG_UDP_INGEST_TOKEN` is set.
- `docs/integrations.md` for OpenTelemetry Collector and Vector.
- `SECURITY.md`, `docs/benchmarks.md`, and `.env.example`.
- Expanded tests: ingest JWT/rate-limit, storage rollup, LiveView dashboard smoke.

### Changed

- Batch persistence uses DuckDB transactions (logs + terms + rollup per flush).
- Production UDP port is not published by default in `docker-compose.prod.yml`.
- Removed unused in-memory `TokenIndex` (single search path in DuckDB).

### Security

- Production requires `AURALOG_UDP_INGEST_TOKEN` when UDP ingest is enabled.
- HTTP ingest tenant is always derived from JWT claims.

### Upgrade notes

- If upgrading from pre-1.0 builds, reset the DuckDB volume or delete `auralog.duckdb` so `logs_1m` is created with a primary key for rollup upserts.
