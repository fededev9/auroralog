defmodule AuraLog.Query.Service do
  @moduledoc """
  Query facade for dashboard aggregates and filtered log retrieval.
  """

  require Logger

  alias AuraLog.Storage.DuckDB
  alias AuraLog.Storage.Schema

  def throughput(_window_seconds \\ 60) do
    with_conn(fn conn ->
      case conn do
        :no_conn ->
          %{rps: 0.0, total: 0}

        _ ->
          case DuckDB.query_rows(conn, Schema.throughput_query_sql(), [60]) do
            {:ok, [row | _]} ->
              total = to_int(row["total"])
              %{rps: Float.round(total / 60, 2), total: total}

            {:ok, _} ->
              %{rps: 0.0, total: 0}

            {:error, reason} ->
              Logger.error("DuckDB throughput query failed: #{inspect(reason)}")
              %{rps: 0.0, total: 0}
          end
      end
    end)
  end

  def error_rates(_window_seconds \\ 300) do
    with_conn(fn conn ->
      case conn do
        :no_conn ->
          %{status_4xx: 0, status_5xx: 0}

        _ ->
          case DuckDB.query_rows(conn, Schema.error_rate_query_sql(), [300]) do
            {:ok, [row | _]} ->
              %{
                status_4xx: to_int(row["status_4xx"]),
                status_5xx: to_int(row["status_5xx"])
              }

            {:ok, _} ->
              %{status_4xx: 0, status_5xx: 0}

            {:error, reason} ->
              Logger.error("DuckDB error-rate query failed: #{inspect(reason)}")
              %{status_4xx: 0, status_5xx: 0}
          end
      end
    end)
  end

  def search(query, opts \\ []) do
    if String.trim(query) == "" do
      []
    else
      with_conn(fn conn ->
        limit = Keyword.get(opts, :limit, 100)
        wildcard = "%#{query}%"

        case conn do
          :no_conn ->
            []

          _ ->
            case DuckDB.query_rows(conn, Schema.search_query_sql(), [
                   wildcard,
                   wildcard,
                   wildcard,
                   limit
                 ]) do
              {:ok, rows} ->
                Enum.map(rows, &normalize_row/1)

              {:error, reason} ->
                Logger.error("DuckDB search query failed: #{inspect(reason)}")
                []
            end
        end
      end)
    end
  end

  defp with_conn(fun) when is_function(fun, 1) do
    database_path = System.get_env("AURALOG_DUCKDB_PATH", "/data/auralog.duckdb")

    case DuckDB.connect(database_path) do
      {:ok, conn} ->
        :ok = DuckDB.bootstrap_schema(conn)

        try do
          fun.(conn)
        after
          DuckDB.close(conn)
        end

      {:error, reason} ->
        Logger.error("Unable to connect DuckDB for query service: #{inspect(reason)}")
        fun.(:no_conn)
    end
  end

  defp normalize_row(%{} = row) do
    %{
      "service" => row["service"],
      "message" => row["message"] || row["raw"],
      "raw" => row["raw"],
      "status_code" => to_int(row["status_code"]),
      "ts" => row["ts"]
    }
  end

  defp to_int(nil), do: 0
  defp to_int(v) when is_integer(v), do: v
  defp to_int(v), do: String.to_integer(to_string(v))
end
