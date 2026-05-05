defmodule AuraLog.Ingest.Dispatcher do
  @moduledoc """
  Entry point for normalized events into the parse/store pipeline.
  """

  use GenServer

  alias AuraLog.Parser.Service
  alias AuraLog.Storage.DuckDBWriter

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def dispatch(event) when is_map(event) do
    GenServer.cast(__MODULE__, {:dispatch, event})
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:dispatch, event}, state) do
    parsed =
      event
      |> List.wrap()
      |> Service.parse_batch()

    Enum.each(parsed.rows, &DuckDBWriter.enqueue/1)
    Enum.each(parsed.errors, &DuckDBWriter.enqueue_error/1)

    {:noreply, state}
  end
end
