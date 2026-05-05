#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-infra/docker/docker-compose.prod.yml}"
CONTAINER_NAME="${CONTAINER_NAME:-auralog}"
DB_PATH_IN_CONTAINER="${DB_PATH_IN_CONTAINER:-/data/auralog.duckdb}"
BACKUP_DIR="${BACKUP_DIR:-infra/docker/backups}"

mkdir -p "${BACKUP_DIR}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TARGET="${BACKUP_DIR}/auralog-${STAMP}.duckdb"

docker compose -f "${COMPOSE_FILE}" ps "${CONTAINER_NAME}" >/dev/null
docker cp "${CONTAINER_NAME}:${DB_PATH_IN_CONTAINER}" "${TARGET}"

echo "Backup created: ${TARGET}"
