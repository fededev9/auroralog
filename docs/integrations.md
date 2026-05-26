# Integrations

AuraLog accepts logs over authenticated HTTP (`POST /api/ingest`). Point collectors at that endpoint with a JWT that includes `sub`, `tenant`, and `exp` claims (HS256, secret `AURALOG_INGEST_JWT_SECRET`).

## Mint a JWT (example)

Use any HS256 JWT tool. Payload example:

```json
{
  "sub": "otel-collector",
  "tenant": "production",
  "exp": 1735689600
}
```

## OpenTelemetry Collector

Export logs through the `otlphttp` exporter to AuraLog. This example uses a transform processor to place the log body in the `raw` field expected by AuraLog.

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  transform/logs_to_raw:
    log_statements:
      - context: log
        statements:
          - set(attributes["raw"], body.string)

exporters:
  otlphttp/auralog:
    logs_endpoint: http://auralog:4000/api/ingest
    headers:
      Authorization: "Bearer ${AURALOG_INGEST_JWT}"

service:
  pipelines:
    logs:
      receivers: [otlp]
      processors: [transform/logs_to_raw]
      exporters: [otlphttp/auralog]
```

Notes:

- Replace `${AURALOG_INGEST_JWT}` with a valid token at deploy time.
- AuraLog does not implement a full OTLP receiver; the collector must map log records to JSON `{"raw":"..."}`.

## Vector

```toml
[sources.app_logs]
type = "file"
include = ["/var/log/app/*.log"]

[transforms.to_auralog]
type = "remap"
inputs = ["app_logs"]
source = '''
. = {"raw": string!(.message)}
'''

[sinks.auralog]
type = "http"
inputs = ["transforms.to_auralog"]
uri = "http://auralog:4000/api/ingest"
method = "post"
encoding.codec = "json"
request.headers.Authorization = "Bearer ${AURALOG_INGEST_JWT}"
```

## UDP (optional, trusted networks only)

When enabled, send JSON datagrams:

```json
{"token":"<AURALOG_UDP_INGEST_TOKEN>","tenant":"production","raw":"service=api message=hello"}
```

See [README](../README.md#udp-ingest-optional) for security requirements.
