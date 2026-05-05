#!/usr/bin/env python3
import json
import os
import random
import socket
import time
import hmac
import hashlib
import base64
import urllib.error
import urllib.request


HTTP_URL = os.getenv("AURALOG_INGEST_HTTP_URL", "http://auralog:4000/api/ingest")
UDP_HOST = os.getenv("AURALOG_INGEST_UDP_HOST", "auralog")
UDP_PORT = int(os.getenv("AURALOG_INGEST_UDP_PORT", "9000"))
BURST_SIZE = int(os.getenv("AURALOG_SEED_BURST_SIZE", "2000"))
RATE_PER_SEC = int(os.getenv("AURALOG_SEED_RATE", "300"))
WARMUP_RETRIES = int(os.getenv("AURALOG_WARMUP_RETRIES", "60"))
JWT_SECRET = os.getenv("AURALOG_INGEST_JWT_SECRET", "dev-jwt-secret-change-me")
JWT_SUBJECT = os.getenv("AURALOG_INGEST_JWT_SUBJECT", "demo-seeder")
JWT_TENANT = os.getenv("AURALOG_INGEST_JWT_TENANT", "demo")


PATHS = ["/", "/health", "/api/login", "/api/orders", "/assets/app.js"]
METHODS = ["GET", "POST", "PUT", "DELETE"]
STATUS_CODES = [200, 201, 204, 400, 401, 403, 404, 500, 502, 503]


def now_rfc3339():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("utf-8")


def build_jwt_token():
    header = {"alg": "HS256", "typ": "JWT"}
    now = int(time.time())
    payload = {
        "sub": JWT_SUBJECT,
        "tenant": JWT_TENANT,
        "iat": now,
        "exp": now + 3600,
    }

    header_part = b64url(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_part = b64url(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_part}.{payload_part}".encode("utf-8")
    signature = hmac.new(JWT_SECRET.encode("utf-8"), signing_input, hashlib.sha256).digest()
    return f"{header_part}.{payload_part}.{b64url(signature)}"


def wait_for_ingest():
    for _ in range(WARMUP_RETRIES):
        try:
            send_http(build_json_event())
            return
        except Exception:
            time.sleep(1)
    raise RuntimeError("AuraLog HTTP ingest not ready")


def build_json_event():
    status = random.choice(STATUS_CODES)
    path = random.choice(PATHS)
    return {
        "tenant": "demo",
        "timestamp": now_rfc3339(),
        "raw": json.dumps(
            {
                "service": random.choice(["api", "auth", "billing"]),
                "level": "error" if status >= 500 else "info",
                "status_code": status,
                "method": random.choice(METHODS),
                "path": path,
                "message": f"request to {path} returned {status}",
            }
        ),
        "metadata": {"generator": "demo_ingest"},
    }


def build_nginx_line():
    status = random.choice(STATUS_CODES)
    method = random.choice(METHODS)
    path = random.choice(PATHS)
    return (
        f'127.0.0.1 - - [10/Oct/2000:13:55:36 -0700] "{method} {path} HTTP/1.1" '
        f"{status} 1234"
    )


def build_apache_line():
    status = random.choice(STATUS_CODES)
    method = random.choice(METHODS)
    path = random.choice(PATHS)
    return (
        f'10.1.2.3 - - [10/Oct/2000:13:55:36 -0700] "{method} {path} HTTP/1.0" '
        f"{status} 2326"
    )


def send_http(payload):
    token = build_jwt_token()
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        HTTP_URL,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=2) as response:
        if response.status >= 300:
            raise RuntimeError(f"Unexpected status {response.status}")


def send_udp(line, sock):
    sock.sendto(line.encode("utf-8"), (UDP_HOST, UDP_PORT))


def run():
    print("Waiting for AuraLog ingest endpoint...")
    wait_for_ingest()
    print("AuraLog ready. Starting warmup burst.")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        for i in range(BURST_SIZE):
            send_http(build_json_event())
            send_udp(build_nginx_line(), sock)
            send_udp(build_apache_line(), sock)
            if i % 500 == 0 and i > 0:
                print(f"Warmup sent: {i}")

        print("Warmup completed. Switching to steady stream.")
        sleep_interval = 1.0 / max(RATE_PER_SEC, 1)
        while True:
            send_http(build_json_event())
            send_udp(build_nginx_line(), sock)
            send_udp(build_apache_line(), sock)
            time.sleep(sleep_interval)
    finally:
        sock.close()


if __name__ == "__main__":
    try:
        run()
    except urllib.error.URLError as exc:
        raise SystemExit(f"Network error while sending demo logs: {exc}") from exc
