defmodule AuraLog.Storage.DuckDBWriter do
  @moduledoc """
  Buffered batch writer for DuckDB append-only log persistence.

  Owns the shared DuckDB connection used by `AuraLog.Query.Service` for reads.
  """
  use GenServer
  require Logger

  alias AuraLog.Metrics.RuntimeCounters
  alias AuraLog.Search.Tokenizer
  alias AuraLog.Storage.DuckDB

  @insert_log_sql """
  INSERT INTO logs (
    id, ts, ingested_at, tenant, source, host, service, level, status_code,
    method, path, latency_ms, message, raw, attrs_json, parse_ok, parse_error,
    detected_format, schema_version, inference_confidence, inferred_fields_json
  )
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
  """

  @insert_term_sql """
  INSERT INTO log_terms (log_id, term, term_freq, ts)
  VALUES (?, ?, ?, ?);
  """

  @upsert_rollup_sql """
  INSERT INTO logs_1m (bucket_start, tenant, service, status_family, events)
  VALUES (?, ?, ?, ?, ?)
  ON CONFLICT (bucket_start, tenant, service, status_family)
  DO UPDATE SET events = logs_1m.events + excluded.events;
  """

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{rows: [], errors: []}, name: __MODULE__)
  end

  def enqueue(row), do: GenServer.cast(__MODULE__, {:enqueue_row, row})
  def enqueue_error(error), do: GenServer.cast(__MODULE__, {:enqueue_error, error})

  @doc """
  Runs a read query on the writer's DuckDB connection.
  """
  def query_rows(sql, params \\ []) do
    GenServer.call(__MODULE__, {:query_rows, sql, params}, 60_000)
  end

  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    config = Application.get_env(:aura_log, __MODULE__, [])
    database_path = runtime_database_path(config)

    if is_binary(database_path) and database_path not in [":memory:", ":memory"] do
      ensure_parent_dir!(database_path)
    end

    conn =
      case DuckDB.connect(database_path) do
        {:ok, conn} ->
          case DuckDB.bootstrap_schema(conn) do
            :ok ->
              conn

            {:error, reason} ->
              Logger.error("DuckDB schema bootstrap failed: #{inspect(reason)}")
              DuckDB.close(conn)
              nil
          end

        {:error, reason} ->
          Logger.error(
            "DuckDB connection failed, continuing in degraded mode: #{inspect(reason)}"
          )

          nil
      end

    schedule_flush(config[:flush_interval_ms] || 1_000)
    {:ok, state |> Map.put(:config, config) |> Map.put(:db_conn, conn)}
  end

  @impl true
  def handle_call({:query_rows, sql, params}, _from, %{db_conn: conn} = state) do
    result =
      if is_pid(conn) do
        DuckDB.query_rows(conn, sql, params)
      else
        {:ok, []}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_cast({:enqueue_row, row}, state) do
    rows = [row | state.rows]
    max_batch_size = state.config[:max_batch_size] || 1_000

    if length(rows) >= max_batch_size do
      new_state = %{state | rows: rows}
      flush_state(new_state)
    else
      {:noreply, %{state | rows: rows}}
    end
  end

  @impl true
  def handle_cast({:enqueue_error, error}, state),
    do: {:noreply, %{state | errors: [error | state.errors]}}

  @impl true
  def handle_info(:flush, state) do
    flush_state(state)
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{db_conn: pid} = state) do
    Logger.error("DuckDB connection exited: #{inspect(reason)}")
    {:noreply, %{state | db_conn: nil}}
  end

  @impl true
  def terminate(_reason, state) do
    if is_pid(state[:db_conn]), do: DuckDB.close(state.db_conn)
    :ok
  end

  defp flush_state(state) do
    maybe_persist(state.rows, state.errors, state.db_conn)
    schedule_flush(state.config[:flush_interval_ms] || 1_000)
    {:noreply, %{state | rows: [], errors: []}}
  end

  defp maybe_persist([], [], _conn), do: :ok

  defp maybe_persist(rows, errors, conn) do
    row_count = length(rows)
    err_count = length(errors)
    Logger.debug("Persisting #{row_count} rows and #{err_count} parse errors")

    if is_pid(conn) do
      persist_batch(conn, rows)
    else
      Logger.warning("Skipping DuckDB persistence because no DB connection is available")
    end

    RuntimeCounters.record_batch(rows)
    publish_stats(row_count, err_count)
  end

  defp persist_batch(conn, rows) do
    normalized = Enum.map(rows, &normalize_row/1)

    :ok = DuckDB.execute(conn, "BEGIN TRANSACTION", [])

    case insert_logs_and_terms(conn, normalized) do
      :ok ->
        upsert_rollup_buckets(conn, normalized)
        DuckDB.execute(conn, "COMMIT", [])

      {:error, reason} ->
        Logger.error("Batch persist failed, rolling back: #{inspect(reason)}")
        DuckDB.execute(conn, "ROLLBACK", [])
    end
  rescue
    error ->
      Logger.error("Batch persist exception: #{inspect(error)}")
      DuckDB.execute(conn, "ROLLBACK", [])
  end

  defp insert_logs_and_terms(conn, normalized_rows) do
    Enum.reduce_while(normalized_rows, :ok, fn row, :ok ->
      case insert_log_row(conn, row) do
        :ok -> insert_term_rows(conn, row)
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp insert_log_row(conn, row) do
    params = log_insert_params(row, DateTime.utc_now() |> DateTime.to_iso8601())

    case DuckDB.execute(conn, @insert_log_sql, params) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_term_rows(conn, row) do
    terms = terms_for_row(row)

    Enum.reduce_while(terms, :ok, fn term, :ok ->
      freq = term_frequency(term, row)
      params = [row.id, term, freq, row.ts]

      case DuckDB.execute(conn, @insert_term_sql, params) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp terms_for_row(row) do
    [row.message, row.raw, row.service]
    |> Enum.filter(&is_binary/1)
    |> Enum.flat_map(&Tokenizer.terms_for/1)
    |> Enum.uniq()
  end

  defp term_frequency(term, row) do
    haystack = String.downcase("#{row.message} #{row.raw} #{row.service}")
    term = String.downcase(term)

    length(Regex.scan(~r/#{Regex.escape(term)}/, haystack))
    |> max(1)
  end

  defp upsert_rollup_buckets(conn, normalized_rows) do
    normalized_rows
    |> Enum.reduce(%{}, fn row, acc ->
      key =
        {minute_bucket(row.ts), row.tenant, row.service || "unknown",
         status_family(row.status_code)}

      Map.update(acc, key, 1, &(&1 + 1))
    end)
    |> Enum.each(fn {{bucket, tenant, service, family}, count} ->
      DuckDB.execute(conn, @upsert_rollup_sql, [bucket, tenant, service, family, count])
    end)
  end

  defp log_insert_params(row, ingested_at) do
    [
      row.id,
      row.ts,
      ingested_at,
      row.tenant,
      row.source,
      row.host,
      row.service,
      row.level,
      row.status_code,
      row.method,
      row.path,
      row.latency_ms,
      row.message,
      row.raw,
      row.attrs_json,
      row.parse_ok,
      row.parse_error,
      row.detected_format,
      row.schema_version,
      row.inference_confidence,
      row.inferred_fields_json
    ]
  end

  defp minute_bucket(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} ->
        dt |> DateTime.truncate(:second) |> Map.put(:second, 0) |> DateTime.to_iso8601()

      _ ->
        DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    end
  end

  defp minute_bucket(_),
    do: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  defp status_family(code) when is_integer(code) and code >= 500, do: "5xx"
  defp status_family(code) when is_integer(code) and code >= 400, do: "4xx"
  defp status_family(_), do: "ok"

  defp publish_stats(rows, errors) do
    Phoenix.PubSub.broadcast(
      AuraLog.PubSub,
      "dashboard:metrics",
      {:ingest_stats, %{rows_written: rows, errors_count: errors, at: DateTime.utc_now()}}
    )
  end

  defp schedule_flush(ms), do: Process.send_after(self(), :flush, ms)

  defp runtime_database_path(config) do
    case System.get_env("AURALOG_DUCKDB_PATH") do
      nil -> config[:database_path] || "/data/auralog.duckdb"
      path -> path
    end
  end

  defp ensure_parent_dir!(db_path) do
    db_path
    |> Path.dirname()
    |> File.mkdir_p!()
  end

  defp normalize_row(row) when is_map(row) do
    attrs_map = Map.get(row, :metadata) || Map.get(row, "metadata") || %{}

    %{
      id: Map.get(row, :id) || Map.get(row, "id") || unique_id(),
      ts: Map.get(row, :ts) || Map.get(row, "ts") || DateTime.utc_now() |> DateTime.to_iso8601(),
      tenant: Map.get(row, :tenant) || Map.get(row, "tenant") || "default",
      source: Map.get(row, :source) || Map.get(row, "source") || "unknown",
      host: Map.get(row, :host) || Map.get(row, "host"),
      service: Map.get(row, :service) || Map.get(row, "service"),
      level: Map.get(row, :level) || Map.get(row, "level"),
      status_code: parse_integer(Map.get(row, :status_code) || Map.get(row, "status_code")),
      method: Map.get(row, :method) || Map.get(row, "method"),
      path: Map.get(row, :path) || Map.get(row, "path"),
      latency_ms: parse_float(Map.get(row, :latency_ms) || Map.get(row, "latency_ms")),
      message: Map.get(row, :message) || Map.get(row, "message"),
      raw: Map.get(row, :raw) || Map.get(row, "raw") || Map.get(row, :raw_line) || "",
      attrs_json: encode_json(attrs_map),
      parse_ok: parse_ok?(row),
      parse_error: Map.get(row, :parse_error) || Map.get(row, "parse_error"),
      detected_format: Map.get(row, :detected_format) || Map.get(row, "detected_format"),
      schema_version: Map.get(row, :schema_version) || Map.get(row, "schema_version"),
      inference_confidence:
        parse_float(Map.get(row, :inference_confidence) || Map.get(row, "inference_confidence")),
      inferred_fields_json:
        Map.get(row, :inferred_fields_json) || Map.get(row, "inferred_fields_json") || "{}"
    }
  end

  defp parse_ok?(row) do
    parse_error = Map.get(row, :parse_error) || Map.get(row, "parse_error")
    parse_error in [nil, ""]
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) do
    case Integer.parse(to_string(value)) do
      {int, _} -> int
      _ -> nil
    end
  end

  defp parse_float(nil), do: nil
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0

  defp parse_float(value) do
    case Float.parse(to_string(value)) do
      {float, _} -> float
      _ -> nil
    end
  end

  defp encode_json(value) when is_binary(value), do: value
  defp encode_json(value) when is_map(value) or is_list(value), do: Jason.encode!(value)
  defp encode_json(value), do: Jason.encode!(%{"value" => to_string(value)})

  defp unique_id do
    "log_" <> Integer.to_string(System.unique_integer([:positive]))
  end
end
