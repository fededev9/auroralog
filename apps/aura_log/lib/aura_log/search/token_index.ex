defmodule AuraLog.Search.TokenIndex do
  @moduledoc """
  In-memory fallback token index mirroring the planned DuckDB `log_terms` table.
  """
  use GenServer

  alias AuraLog.Parser.NIF

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{docs: %{}, terms: %{}}, name: __MODULE__)
  end

  def index(row), do: GenServer.cast(__MODULE__, {:index, row})
  def count_documents, do: GenServer.call(__MODULE__, :count_documents)
  def search(query, opts \\ []), do: GenServer.call(__MODULE__, {:search, query, opts})

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:index, row}, state) do
    id = Map.get(row, :id) || Map.get(row, "id") || unique_id()
    message = Map.get(row, :message) || Map.get(row, "message") || Map.get(row, :raw, "")
    terms = safe_tokenize(message)

    terms_map =
      Enum.reduce(terms, state.terms, fn term, acc ->
        docs = Map.get(acc, term, MapSet.new()) |> MapSet.put(id)
        Map.put(acc, term, docs)
      end)

    docs_map = Map.put(state.docs, id, Map.put(row, :id, id))
    {:noreply, %{state | docs: docs_map, terms: terms_map}}
  end

  @impl true
  def handle_call(:count_documents, _from, state), do: {:reply, map_size(state.docs), state}

  @impl true
  def handle_call({:search, query, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 100)

    ids =
      query
      |> String.downcase()
      |> String.split(~r/\s+/, trim: true)
      |> Enum.reduce(nil, fn term, acc ->
        docs = Map.get(state.terms, term, MapSet.new())
        if is_nil(acc), do: docs, else: MapSet.intersection(acc, docs)
      end)
      |> case do
        nil -> MapSet.new()
        set -> set
      end

    results =
      ids
      |> MapSet.to_list()
      |> Enum.take(limit)
      |> Enum.map(&Map.get(state.docs, &1))

    {:reply, results, state}
  end

  defp safe_tokenize(message) do
    case NIF.tokenize_for_search(message) do
      {:ok, terms} when is_list(terms) -> terms
      terms when is_list(terms) -> terms
      _ -> fallback_tokenize(message)
    end
  rescue
    _ -> fallback_tokenize(message)
  end

  defp fallback_tokenize(message) do
    message
    |> String.downcase()
    |> String.split(~r/[^a-z0-9_]+/, trim: true)
  end

  defp unique_id do
    "log_" <> Integer.to_string(System.unique_integer([:positive]))
  end
end
