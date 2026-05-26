# AuraLog Architecture

## Data flow

1. Log producers send events through HTTP or UDP.
2. Elixir normalizes each event into a canonical envelope.
3. Dispatcher hands batches to Rust NIF parsers with format/schema auto-inference.
4. Parsed rows are buffered and written in batches to DuckDB.
5. Query service provides throughput/error aggregates and search.
6. LiveView dashboard subscribes to PubSub updates every second.

## Components

- `AuraLog.Ingest.HTTPIngest`: HTTP intake endpoint.
- `AuraLog.Ingest.UDPListener`: firehose UDP intake process.
- `AuraLog.Ingest.Dispatcher`: pipeline gateway with async dispatch.
- `AuraLog.Parser.NIF`: Rustler entry module for parsing/tokenization NIFs.
- `AuraLog.Parser.Service`: format detection + fallback parse orchestration.
- `AuraLog.Storage.DuckDBWriter`: buffered write service and dashboard stat events.
- `AuraLog.Search.Tokenizer`: term extraction for `log_terms` indexing and search.
- `AuraLog.Query.Service`: reusable analytics/search query facade.
- `AuraLogWeb.DashboardLive`: zero-JS real-time dashboard.

## DuckDB schema

Primary table: `logs` with canonical columns (`ts`, `service`, `status_code`, `message`, `attrs_json`, parse metadata).  
Search table: `log_terms` mapping `log_id -> term`.

## Performance model

- CPU-heavy work in Rust dirty schedulers.
- Batch processing to minimize BEAM <-> NIF overhead.
- Time-window aggregations designed for pre-aggregation in Rust (phase 2).
- Pattern matching and inference metadata (`detected_format`, `inference_confidence`) are emitted by parser outputs.
