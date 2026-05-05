defmodule AuraLog.Storage.Schema do
  @moduledoc """
  DuckDB schema definitions for analytical log storage.
  """

  @logs_table """
  CREATE TABLE IF NOT EXISTS logs (
    id VARCHAR,
    ts TIMESTAMP,
    ingested_at TIMESTAMP,
    tenant VARCHAR,
    source VARCHAR,
    host VARCHAR,
    service VARCHAR,
    level VARCHAR,
    status_code INTEGER,
    method VARCHAR,
    path VARCHAR,
    latency_ms DOUBLE,
    message VARCHAR,
    raw VARCHAR,
    attrs_json JSON,
    parse_ok BOOLEAN,
    parse_error VARCHAR,
    detected_format VARCHAR,
    schema_version VARCHAR,
    inference_confidence DOUBLE,
    inferred_fields_json JSON
  );
  """

  @log_terms_table """
  CREATE TABLE IF NOT EXISTS log_terms (
    log_id VARCHAR,
    term VARCHAR,
    term_freq INTEGER,
    ts TIMESTAMP
  );
  """

  @logs_rollup_table """
  CREATE TABLE IF NOT EXISTS logs_1m (
    bucket_start TIMESTAMP,
    tenant VARCHAR,
    service VARCHAR,
    status_family VARCHAR,
    events BIGINT
  );
  """

  @dashboard_query """
  SELECT
    date_trunc('minute', ts) AS bucket_start,
    service,
    count(*) AS events,
    count_if(status_code BETWEEN 400 AND 499) AS errors_4xx,
    count_if(status_code >= 500) AS errors_5xx
  FROM logs
  WHERE ts >= now() - INTERVAL 15 MINUTE
  GROUP BY 1, 2
  ORDER BY bucket_start DESC;
  """

  @throughput_query """
  SELECT count(*)::BIGINT AS total
  FROM logs
  WHERE ts >= now() - (? * INTERVAL 1 SECOND);
  """

  @error_rate_query """
  SELECT
    count(*) FILTER (WHERE status_code BETWEEN 400 AND 499)::BIGINT AS status_4xx,
    count(*) FILTER (WHERE status_code >= 500)::BIGINT AS status_5xx
  FROM logs
  WHERE ts >= now() - (? * INTERVAL 1 SECOND);
  """

  @search_query """
  SELECT service, message, raw, status_code, ts
  FROM logs
  WHERE lower(raw) LIKE lower(?)
     OR lower(message) LIKE lower(?)
     OR lower(service) LIKE lower(?)
  ORDER BY ts DESC
  LIMIT ?;
  """

  @log_indexes [
    "CREATE INDEX IF NOT EXISTS logs_ts_idx ON logs(ts);",
    "CREATE INDEX IF NOT EXISTS logs_tenant_idx ON logs(tenant);",
    "CREATE INDEX IF NOT EXISTS logs_status_idx ON logs(status_code);"
  ]

  def logs_table_sql, do: @logs_table
  def log_terms_sql, do: @log_terms_table
  def logs_rollup_sql, do: @logs_rollup_table
  def dashboard_query_sql, do: @dashboard_query
  def throughput_query_sql, do: @throughput_query
  def error_rate_query_sql, do: @error_rate_query
  def search_query_sql, do: @search_query

  def bootstrap_sql do
    [@logs_table, @log_terms_table, @logs_rollup_table] ++ @log_indexes
  end
end
