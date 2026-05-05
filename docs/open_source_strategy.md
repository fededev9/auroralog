# Open Source Strategy

## Repository structure

- `apps/aura_log`: ingestion, parser orchestration, storage/query layer.
- `apps/aura_log_web`: Phoenix LiveView user interface.
- `native/auralog_core`: Rust performance modules.
- `infra/docker`: install and runtime artifacts.
- `docs`: architecture, roadmap, contracts, schema.

## Installability principles

- Single command bring-up via Docker Compose.
- Explicit runtime volumes for DuckDB persistence.
- Profiles for `dev`, `single-node-prod`, and `benchmark`.

## Governance baseline

- Apache-2.0 license baseline.
- Contributor docs and behavior policy included.
- Bug/feature issue templates for triage consistency.

## DX and automation

- CI checks: format, compile, test.
- Makefile commands for common contributor workflows.
