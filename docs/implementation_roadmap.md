# Implementation Roadmap

## Phase 0 - Bootstrap

- Umbrella repository with `aura_log` core + `aura_log_web` UI.
- Native Rust crate integrated via Rustler.
- CI pipeline and contributor baseline documents.

## Phase 1 - Ingestion reliability

- HTTP endpoint and UDP listener.
- Normalized envelope (`tenant`, `source`, `timestamp`, `raw_line`, `metadata`).
- Asynchronous dispatch to parsing/storage.

## Phase 2 - Parsing performance

- NIF functions for Nginx, Apache, JSON parse.
- Format detection and search tokenization.
- Dirty CPU schedulers for heavy workloads.

## Phase 3 - Storage and analytics

- DuckDB schema bootstrap (`logs`, `log_terms`, `logs_1m`).
- Buffered writer and periodic flush strategy.
- Query facade for throughput/error/search.

## Phase 4 - Realtime dashboard

- LiveView dashboard with periodic snapshot refresh.
- PubSub-based updates from ingest pipeline.
- Throughput/error KPIs and text search UX.

## Phase 5 - OSS packaging

- Docker image and compose profile.
- Makefile task runner for setup/test/lint/run/bench.
- CONTRIBUTING, CODE_OF_CONDUCT, issue templates.
