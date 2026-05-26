defmodule AuraLog.Query.Service do
  @moduledoc """
  Query facade for dashboard aggregates and term-based log search.

  Reads use the shared DuckDB connection owned by `AuraLog.Storage.DuckDBWriter`.
  """

  require Logger

  alias AuraLog.Search.Tokenizer
  alias AuraLog.Storage.DuckDBWriter
  alias AuraLog.Storage.Schema

  def throughput(window_seconds \\ 60) do
    total =
      if rollup_table_populated?() do
        case DuckDBWriter.query_rows(Schema.throughput_rollup_query_sql(), [window_seconds]) do
          {:ok, [row | _]} -> to_int(row["total"])
          _ -> 0
        end
      else
        logs_throughput(window_seconds)
      end

    %{rps: Float.round(total / window_seconds, 2), total: total}
  end

  def error_rates(window_seconds \\ 300) do
    if rollup_table_populated?() do
      rollup_error_rates(window_seconds)
    else
      logs_error_rates(window_seconds)
    end
  end

  def search(query, opts \\ []) do
    terms = Tokenizer.query_terms(query)

    cond do
      terms == [] ->
        []

      length(terms) == 1 ->
        term_search(List.first(terms), opts)

      true ->
        multi_term_search(terms, opts)
    end
  end

  defp term_search(term, opts) do
    limit = Keyword.get(opts, :limit, 100)

    case DuckDBWriter.query_rows(Schema.search_term_query_sql(), [term, limit]) do
      {:ok, rows} ->
        Enum.map(rows, &normalize_row/1)

      {:error, reason} ->
        Logger.error("DuckDB term search failed: #{inspect(reason)}")
        []
    end
  end

  defp multi_term_search(terms, opts) do
    limit = Keyword.get(opts, :limit, 100)
    sql = Schema.search_multi_term_sql(length(terms))
    params = terms ++ [limit]

    case DuckDBWriter.query_rows(sql, params) do
      {:ok, rows} ->
        Enum.map(rows, &normalize_row/1)

      {:error, reason} ->
        Logger.error("DuckDB multi-term search failed: #{inspect(reason)}")
        []
    end
  end

  defp rollup_table_populated? do
    case DuckDBWriter.query_rows(Schema.rollup_has_data_query_sql(), []) do
      {:ok, [%{"cnt" => cnt}]} -> to_int(cnt) > 0
      _ -> false
    end
  end

  defp logs_throughput(window_seconds) do
    case DuckDBWriter.query_rows(Schema.throughput_logs_query_sql(), [window_seconds]) do
      {:ok, [%{"total" => total} | _]} -> to_int(total)
      _ -> 0
    end
  end

  defp rollup_error_rates(window_seconds) do
    case DuckDBWriter.query_rows(Schema.error_rate_rollup_query_sql(), [window_seconds]) do
      {:ok, [row | _]} ->
        %{
          status_4xx: to_int(row["status_4xx"]),
          status_5xx: to_int(row["status_5xx"])
        }

      {:ok, _} ->
        %{status_4xx: 0, status_5xx: 0}

      {:error, reason} ->
        Logger.error("DuckDB rollup error-rate query failed: #{inspect(reason)}")
        %{status_4xx: 0, status_5xx: 0}
    end
  end

  defp logs_error_rates(window_seconds) do
    case DuckDBWriter.query_rows(Schema.error_rate_logs_query_sql(), [window_seconds]) do
      {:ok, [row | _]} ->
        %{
          status_4xx: to_int(row["status_4xx"]),
          status_5xx: to_int(row["status_5xx"])
        }

      {:ok, _} ->
        %{status_4xx: 0, status_5xx: 0}

      {:error, reason} ->
        Logger.error("DuckDB logs error-rate query failed: #{inspect(reason)}")
        %{status_4xx: 0, status_5xx: 0}
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
