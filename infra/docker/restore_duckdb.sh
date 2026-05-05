#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <backup-file.duckdb>"
  exit 1
fi

BACKUP_FILE="$1"
COMPOSE_FILE="${COMPOSE_FILE:-infra/docker/docker-compose.prod.yml}"
CONTAINER_NAME="${CONTAINER_NAME:-auralog}"
DB_PATH_IN_CONTAINER="${DB_PATH_IN_CONTAINER:-/data/auralog.duckdb}"

if [[ ! -f "${BACKUP_FILE}" ]]; then
  echo "Backup file not found: ${BACKUP_FILE}"
  exit 1
fi

docker compose -f "${COMPOSE_FILE}" stop "${CONTAINER_NAME}"
docker compose -f "${COMPOSE_FILE}" up -d "${CONTAINER_NAME}"
docker cp "${BACKUP_FILE}" "${CONTAINER_NAME}:${DB_PATH_IN_CONTAINER}"
docker compose -f "${COMPOSE_FILE}" restart "${CONTAINER_NAME}"

echo "Restore completed from ${BACKUP_FILE}"
