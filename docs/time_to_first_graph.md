# Time-to-First-Graph Verification

This checklist validates the first-release setup goal: clone repo, run one command, immediately see moving charts.

## Command

```bash
docker compose -f infra/docker/docker-compose.yml up --build
```

## Expected sequence

1. `auralog` image builds using the Rust-enabled builder stage.
2. `auralog` container starts and exposes:
   - HTTP on `4000`
   - UDP ingest on `9000`
3. `seed_ingest` waits for app health and starts log generation.
4. Dashboard at `http://localhost:4000/dashboard` shows non-zero throughput and changing values.

## Acceptance checks

- No external database service is required.
- DuckDB file is persisted in Docker volume (`/data/auralog.duckdb`).
- Demo stream includes Nginx, Apache, and JSON lines.
- Parser auto-detection works without user configuration.
