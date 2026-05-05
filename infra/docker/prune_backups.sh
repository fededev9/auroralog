#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-infra/docker/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

mkdir -p "${BACKUP_DIR}"
find "${BACKUP_DIR}" -type f -name "auralog-*.duckdb" -mtime +"${RETENTION_DAYS}" -print -delete
echo "Pruned backups older than ${RETENTION_DAYS} days from ${BACKUP_DIR}"
