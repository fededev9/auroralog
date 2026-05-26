# Benchmarks (indicative)

These numbers are **not** official SLAs. They document a local smoke benchmark on a single-node Docker deployment with the demo profile. Reproduce on your hardware before capacity planning.

## Environment (reference)

- Docker Compose demo profile
- Single AuraLog container
- DuckDB file on a local volume
- Synthetic JSON / Nginx / Apache lines via `seed_ingest`

## Observed (order of magnitude)

| Metric | Typical range |
| ------ | ------------- |
| HTTP ingest acceptance | Low thousands of events/sec per core (JWT + parse + buffer) |
| Dashboard refresh | 1 second LiveView tick + PubSub on flush |
| Search (term index) | Milliseconds for recent data; scales with `log_terms` size |
| Storage | Single `auralog.duckdb` file; vertical scaling only in v1.0 |

## Bottlenecks in v1.0

- Single DuckDB writer connection (by design for consistency).
- Per-batch transaction with term indexing and rollup upserts.
- No horizontal sharding or object-storage tier.

For production sizing, run your own load test against `POST /api/ingest` with representative log lines and monitor disk growth under `AURALOG_DUCKDB_PATH`.
