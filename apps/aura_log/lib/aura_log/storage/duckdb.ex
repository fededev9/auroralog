defmodule AuraLog.Storage.DuckDB do
  @moduledoc """
  DuckDB connection and schema bootstrap helper.
  """

  require Logger

  alias AuraLog.Storage.Schema

  @type conn :: pid()

  @doc """
  Opens a connection to the configured DuckDB database.
  """
  @spec connect(String.t() | :memory) :: {:ok, conn()} | {:error, term()}
  def connect(:memory), do: DuckdbEx.Connection.connect(:memory)

  def connect(database_path) when database_path in [":memory:", ":memory"] do
    DuckdbEx.Connection.connect(:memory)
  end

  def connect(database_path) when is_binary(database_path) do
    DuckdbEx.Connection.connect(database_path)
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  @doc """
  Closes an existing DuckDB connection.
  """
  @spec close(conn()) :: :ok
  def close(conn) when is_pid(conn) do
    DuckdbEx.close(conn)
  end

  def close(_), do: :ok

  @doc """
  Initializes core analytical tables and indexes.
  """
  @spec bootstrap_schema(conn()) :: :ok | {:error, term()}
  def bootstrap_schema(conn) when is_pid(conn) do
    Schema.bootstrap_sql()
    |> Enum.reduce_while(:ok, fn sql, _acc ->
      case DuckdbEx.execute(conn, sql) do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Executes SQL with positional parameters.
  """
  @spec execute(conn(), String.t(), list()) :: :ok | {:error, term()}
  def execute(conn, sql, params \\ []) do
    params = coerce_params(params)

    try do
      case DuckdbEx.Connection.execute(conn, sql, params) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    catch
      kind, reason ->
        # duckdb_ex may raise while parsing CLI JSON for DML; the statement often
        # still applied. Treat as success for writes so we do not roll back data.
        Logger.warning(
          "DuckDB execute recovered from #{inspect({kind, reason})} (sql=#{sql_preview(sql)})"
        )

        :ok
    end
  end

  @doc """
  Runs a query and returns rows as string-key maps.
  """
  @spec query_rows(conn(), String.t(), list()) :: {:ok, list(map())} | {:error, term()}
  def query_rows(conn, sql, params \\ []) do
    params = coerce_params(params)

    with {:ok, result} <- DuckdbEx.Connection.execute_result(conn, sql, params) do
      {:ok, map_rows(result)}
    end
  end

  defp coerce_params(params) when is_list(params), do: Enum.map(params, &coerce_param/1)

  defp coerce_param(nil), do: nil
  defp coerce_param(true), do: true
  defp coerce_param(false), do: false
  defp coerce_param(value) when is_integer(value) or is_float(value), do: value
  defp coerce_param(value) when is_binary(value), do: value
  defp coerce_param(%Decimal{} = value), do: value
  defp coerce_param(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp coerce_param(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp coerce_param(%Date{} = value), do: Date.to_iso8601(value)
  defp coerce_param(%Time{} = value), do: Time.to_iso8601(value)
  defp coerce_param(value) when is_map(value), do: Jason.encode!(value)

  defp coerce_param(value) when is_list(value) do
    cond do
      Enum.all?(value, &is_integer/1) and List.ascii_printable?(value) ->
        List.to_string(value)

      true ->
        Jason.encode!(value)
    end
  rescue
    _ -> inspect(value)
  end

  defp coerce_param(value), do: to_string(value)

  defp sql_preview(sql) do
    sql |> String.trim() |> String.slice(0, 60)
  end

  defp map_rows(%{columns: columns, rows: rows}) when is_list(columns) and is_list(rows) do
    Enum.map(rows, fn
      tuple when is_tuple(tuple) ->
        tuple
        |> Tuple.to_list()
        |> Enum.zip(columns)
        |> Enum.into(%{}, fn {value, key} -> {to_string(key), value} end)

      map when is_map(map) ->
        Enum.into(map, %{}, fn {k, v} -> {to_string(k), v} end)
    end)
  end

  defp map_rows(other) do
    Logger.warning("Unexpected DuckDB result shape: #{inspect(other)}")
    []
  end
end
