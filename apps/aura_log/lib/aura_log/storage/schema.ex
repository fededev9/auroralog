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
    events BIGINT,
    PRIMARY KEY (bucket_start, tenant, service, status_family)
  );
  """

  @throughput_rollup_query """
  SELECT coalesce(sum(events), 0)::BIGINT AS total
  FROM logs_1m
  WHERE bucket_start >= now() - (? * INTERVAL 1 SECOND);
  """

  @throughput_logs_query """
  SELECT count(*)::BIGINT AS total
  FROM logs
  WHERE ts >= now() - (? * INTERVAL 1 SECOND);
  """

  @error_rate_rollup_query """
  SELECT
    coalesce(sum(events) FILTER (WHERE status_family = '4xx'), 0)::BIGINT AS status_4xx,
    coalesce(sum(events) FILTER (WHERE status_family = '5xx'), 0)::BIGINT AS status_5xx
  FROM logs_1m
  WHERE bucket_start >= now() - (? * INTERVAL 1 SECOND);
  """

  @error_rate_logs_query """
  SELECT
    count(*) FILTER (WHERE status_code BETWEEN 400 AND 499)::BIGINT AS status_4xx,
    count(*) FILTER (WHERE status_code >= 500)::BIGINT AS status_5xx
  FROM logs
  WHERE ts >= now() - (? * INTERVAL 1 SECOND);
  """

  @rollup_has_data_query """
  SELECT count(*)::BIGINT AS cnt FROM logs_1m LIMIT 1;
  """

  @search_term_query """
  SELECT l.service, l.message, l.raw, l.status_code, l.ts
  FROM logs l
  WHERE l.id IN (
    SELECT log_id
    FROM log_terms
    WHERE term = ?
    GROUP BY log_id
  )
  ORDER BY l.ts DESC
  LIMIT ?;
  """

  @search_multi_term_query """
  SELECT l.service, l.message, l.raw, l.status_code, l.ts
  FROM logs l
  WHERE l.id IN (
    SELECT log_id
    FROM log_terms
    WHERE term IN ({PLACEHOLDERS})
    GROUP BY log_id
    HAVING count(DISTINCT term) = {TERM_COUNT}
  )
  ORDER BY l.ts DESC
  LIMIT ?;
  """

  @log_indexes [
    "CREATE INDEX IF NOT EXISTS logs_ts_idx ON logs(ts);",
    "CREATE INDEX IF NOT EXISTS logs_tenant_idx ON logs(tenant);",
    "CREATE INDEX IF NOT EXISTS logs_status_idx ON logs(status_code);",
    "CREATE INDEX IF NOT EXISTS log_terms_term_idx ON log_terms(term);",
    "CREATE INDEX IF NOT EXISTS log_terms_log_id_idx ON log_terms(log_id);"
  ]

  def logs_table_sql, do: @logs_table
  def log_terms_sql, do: @log_terms_table
  def logs_rollup_sql, do: @logs_rollup_table
  def throughput_rollup_query_sql, do: @throughput_rollup_query
  def throughput_logs_query_sql, do: @throughput_logs_query
  def error_rate_rollup_query_sql, do: @error_rate_rollup_query
  def error_rate_logs_query_sql, do: @error_rate_logs_query
  def rollup_has_data_query_sql, do: @rollup_has_data_query
  def search_term_query_sql, do: @search_term_query

  @doc """
  Builds a parameterized multi-term search SQL string and placeholder list.
  """
  def search_multi_term_sql(term_count) do
    placeholders = Enum.map_join(1..term_count, ", ", fn _ -> "?" end)

    @search_multi_term_query
    |> String.replace("{PLACEHOLDERS}", placeholders)
    |> String.replace("{TERM_COUNT}", Integer.to_string(term_count))
  end

  def bootstrap_sql do
    [@logs_table, @log_terms_table, @logs_rollup_table] ++ @log_indexes
  end
end
