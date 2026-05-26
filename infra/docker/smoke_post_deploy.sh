#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:4000}"
JWT_SECRET="${AURALOG_INGEST_JWT_SECRET:-}"
JWT_SUBJECT="${JWT_SUBJECT:-smoke-runner}"
JWT_TENANT="${JWT_TENANT:-smoke}"
WAIT_ATTEMPTS="${SMOKE_WAIT_ATTEMPTS:-60}"
WAIT_SECONDS="${SMOKE_WAIT_SECONDS:-2}"

if [[ -z "${JWT_SECRET}" ]]; then
  echo "AURALOG_INGEST_JWT_SECRET is required"
  exit 1
fi

wait_for_health() {
  local attempt=1

  until curl -fsS "${BASE_URL}/health" >/dev/null 2>&1; do
    if [[ "${attempt}" -ge "${WAIT_ATTEMPTS}" ]]; then
      echo "Health check failed after ${WAIT_ATTEMPTS} attempts (${BASE_URL}/health)"
      return 1
    fi

    echo "Waiting for ${BASE_URL}/health (${attempt}/${WAIT_ATTEMPTS})..."
    sleep "${WAIT_SECONDS}"
    attempt=$((attempt + 1))
  done
}

token="$(
python - <<'PY'
import base64, hashlib, hmac, json, os, time
secret = os.environ["AURALOG_INGEST_JWT_SECRET"].encode()
sub = os.environ.get("JWT_SUBJECT", "smoke-runner")
tenant = os.environ.get("JWT_TENANT", "smoke")
now = int(time.time())
hdr = {"alg":"HS256","typ":"JWT"}
pl = {"sub": sub, "tenant": tenant, "iat": now, "exp": now + 3600}
enc = lambda x: base64.urlsafe_b64encode(json.dumps(x, separators=(",", ":")).encode()).rstrip(b"=").decode()
h = enc(hdr); p = enc(pl)
sig = hmac.new(secret, f"{h}.{p}".encode(), hashlib.sha256).digest()
print(f"{h}.{p}.{base64.urlsafe_b64encode(sig).rstrip(b'=').decode()}")
PY
)"

echo "Checking health endpoint..."
if ! wait_for_health; then
  echo "Hint: docker compose -f infra/docker/docker-compose.prod.yml logs"
  exit 56
fi

echo "Posting ingest event with JWT..."
curl -fsS -X POST "${BASE_URL}/api/ingest" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${token}" \
  -d "{\"raw\":\"{\\\"service\\\":\\\"smoke\\\",\\\"message\\\":\\\"post_deploy_smoke\\\",\\\"status_code\\\":200}\"}" >/dev/null

echo "Waiting for DuckDB flush..."
sleep 3

echo "Checking dashboard reachable..."
curl -fsS "${BASE_URL}/dashboard?q=post_deploy_smoke" >/dev/null

echo "Smoke test completed successfully."
