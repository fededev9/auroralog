# Security Policy

## Supported versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a vulnerability

Please **do not** open public GitHub issues for security-sensitive reports.

Email the maintainers with:

- Description and impact
- Steps to reproduce
- Affected version / commit

We aim to acknowledge reports within 5 business days.

## Secure deployment checklist

- Set strong `SECRET_KEY_BASE` and `AURALOG_INGEST_JWT_SECRET` (never commit them).
- Keep `AURALOG_UDP_INGEST_ENABLED=false` unless UDP is required on a trusted network.
- When UDP is enabled, always set `AURALOG_UDP_INGEST_TOKEN` and use the JSON payload format.
- Do not expose UDP port `9000` to the public internet.
- Run production with `infra/docker/docker-compose.prod.yml` defaults (HTTP only).
- Back up `auralog.duckdb` regularly (`infra/docker/backup_duckdb.sh`).
