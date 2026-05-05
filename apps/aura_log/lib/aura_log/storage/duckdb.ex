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
  @spec connect(String.t()) :: {:ok, conn()} | {:error, term()}
  def connect(database_path) do
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
    case DuckdbEx.Connection.execute(conn, sql, params) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Runs a query and returns rows as string-key maps.
  """
  @spec query_rows(conn(), String.t(), list()) :: {:ok, list(map())} | {:error, term()}
  def query_rows(conn, sql, params \\ []) do
    with {:ok, result} <- DuckdbEx.Connection.execute_result(conn, sql, params) do
      {:ok, map_rows(result)}
    end
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
