#!/usr/bin/env bash
# Installs the DuckDB CLI without starting the Elixir application.
# Used in CI and Docker build (mix duckdb_ex.install calls app.start, which fails too early).
set -euo pipefail

DEST_DIR="${1:-priv/duckdb}"
mkdir -p "${DEST_DIR}"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "${OS}" in
  Linux) PLATFORM_OS="linux" ;;
  Darwin) PLATFORM_OS="osx" ;;
  *)
    echo "Unsupported OS: ${OS}" >&2
    exit 1
    ;;
esac

case "${ARCH}" in
  x86_64 | amd64) PLATFORM_ARCH="amd64" ;;
  aarch64 | arm64) PLATFORM_ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: ${ARCH}" >&2
    exit 1
    ;;
esac

VERSION="$(curl -fsSL https://duckdb.org/data/latest_stable_version.txt | tr -d '[:space:]')"
VERSION="${VERSION#v}"
DEST="${DEST_DIR}/duckdb"

if [[ "${PLATFORM_OS}" == "linux" ]]; then
  DIST="linux-${PLATFORM_ARCH}"
  URL="https://install.duckdb.org/v${VERSION}/duckdb_cli-${DIST}.gz"
  echo "Installing DuckDB CLI v${VERSION} (${DIST}) to ${DEST}..."
  curl -fsSL "${URL}" | gunzip > "${DEST}"
elif [[ "${PLATFORM_OS}" == "osx" ]]; then
  DIST="osx-${PLATFORM_ARCH}"
  URL="https://install.duckdb.org/v${VERSION}/duckdb_cli-${DIST}.gz"
  echo "Installing DuckDB CLI v${VERSION} (${DIST}) to ${DEST}..."
  curl -fsSL "${URL}" | gunzip > "${DEST}"
else
  echo "Unsupported platform" >&2
  exit 1
fi

chmod +x "${DEST}"
"${DEST}" -c "SELECT 42 AS ok;" >/dev/null
echo "DuckDB CLI ready at ${DEST}"
