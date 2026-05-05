# Rust NIF Contracts

## Functions

- `parse_nginx_lines(batch, opts) -> {:ok, rows}`
- `parse_apache_lines(batch, opts) -> {:ok, rows}`
- `parse_json_lines(batch, opts) -> {:ok, rows}`
- `detect_format(line) -> {:ok, "nginx" | "apache" | "json"}`
- `extract_common_fields(row) -> {:ok, normalized_row}`
- `tokenize_for_search(text) -> {:ok, terms}`
- `aggregate_time_window(rows, window, dimensions) -> {:ok, grouped_counts}`

## Rules

- NIFs run with dirty CPU schedulers for parsing/aggregation/tokenization.
- Inputs are batch-oriented to reduce FFI overhead.
- Outputs are map-based and string-key friendly for BEAM interoperability.
- Parsing failures should be expressed as structured fields (`parse_error`) not process crashes.
