# Data Schema and Query Strategy

## Core table: `logs`

- Event identity: `id`, `tenant`, `source`
- Time semantics: `ts`, `ingested_at`
- HTTP dimensions: `method`, `path`, `status_code`
- Service dimensions: `host`, `service`, `level`
- Payload columns: `message`, `raw`, `attrs_json`
- Quality columns: `parse_ok`, `parse_error`

## Search table: `log_terms`

- `(log_id, term, term_freq, ts)` supports token-based search and relevance scoring.

## Rollup table: `logs_1m`

- Pre-aggregated minute buckets for fast dashboard queries.
- Keys: `bucket_start`, `tenant`, `service`, `status_family`.

## Query profile

- Throughput widgets: aggregate over `logs_1m` first, fallback to `logs`.
- Error widgets: `count_if(status_code BETWEEN 400 AND 499)` and `count_if(status_code >= 500)`.
- Search: terms lookup + recency ordering, with bounded page size.
