defmodule AuraLog.Storage.DuckDBWriter do
  @moduledoc """
  Buffered batch writer for DuckDB append-only log persistence.
  """
  use GenServer
  require Logger

  alias AuraLog.Metrics.RuntimeCounters
  alias AuraLog.Storage.DuckDB

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{rows: [], errors: []}, name: __MODULE__)
  end

  def enqueue(row), do: GenServer.cast(__MODULE__, {:enqueue_row, row})
  def enqueue_error(error), do: GenServer.cast(__MODULE__, {:enqueue_error, error})

  @impl true
  def init(state) do
    Process.flag(:trap_exit, true)
    config = Application.get_env(:aura_log, __MODULE__, [])
    database_path = runtime_database_path(config)
    ensure_parent_dir!(database_path)

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
    maybe_persist(state.rows, state.errors, state.db_conn, state.config)
    schedule_flush(state.config[:flush_interval_ms] || 1_000)
    {:noreply, %{state | rows: [], errors: []}}
  end

  defp maybe_persist([], [], _conn, _config), do: :ok

  defp maybe_persist(rows, errors, conn, _config) do
    row_count = length(rows)
    err_count = length(errors)
    Logger.debug("Persisting #{row_count} rows and #{err_count} parse errors")

    if is_pid(conn) do
      Enum.each(rows, &persist_row(conn, &1))
    else
      Logger.warning("Skipping DuckDB persistence because no DB connection is available")
    end

    RuntimeCounters.record_batch(rows)
    publish_stats(row_count, err_count)
  end

  defp persist_row(conn, row) do
    normalized = normalize_row(row)

    sql = """
    INSERT INTO logs (
      id, ts, ingested_at, tenant, source, host, service, level, status_code,
      method, path, latency_ms, message, raw, attrs_json, parse_ok, parse_error,
      detected_format, schema_version, inference_confidence, inferred_fields_json
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    params = [
      normalized.id,
      normalized.ts,
      DateTime.utc_now() |> DateTime.to_iso8601(),
      normalized.tenant,
      normalized.source,
      normalized.host,
      normalized.service,
      normalized.level,
      normalized.status_code,
      normalized.method,
      normalized.path,
      normalized.latency_ms,
      normalized.message,
      normalized.raw,
      normalized.attrs_json,
      normalized.parse_ok,
      normalized.parse_error,
      normalized.detected_format,
      normalized.schema_version,
      normalized.inference_confidence,
      normalized.inferred_fields_json
    ]

    case DuckDB.execute(conn, sql, params) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error("DuckDB insert failed: #{inspect(reason)} row=#{inspect(row)}")
    end
  end

  defp publish_stats(rows, errors) do
    Phoenix.PubSub.broadcast(
      AuraLog.PubSub,
      "dashboard:metrics",
      {:ingest_stats, %{rows_written: rows, errors_count: errors, at: DateTime.utc_now()}}
    )
  end

  defp schedule_flush(ms), do: Process.send_after(self(), :flush, ms)

  defp runtime_database_path(config) do
    System.get_env("AURALOG_DUCKDB_PATH") || config[:database_path] || "/data/auralog.duckdb"
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
