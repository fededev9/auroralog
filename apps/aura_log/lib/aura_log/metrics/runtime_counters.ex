defmodule AuraLog.Metrics.RuntimeCounters do
  @moduledoc """
  In-memory counters for dashboard throughput and error families.
  """
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{total: 0, status_4xx: 0, status_5xx: 0}, name: __MODULE__)
  end

  def record_batch(rows) when is_list(rows), do: GenServer.cast(__MODULE__, {:record_batch, rows})
  def snapshot, do: GenServer.call(__MODULE__, :snapshot)

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({:record_batch, rows}, state) do
    delta_4xx = Enum.count(rows, &(status_family(&1) == :s4xx))
    delta_5xx = Enum.count(rows, &(status_family(&1) == :s5xx))

    {:noreply,
     %{
       state
       | total: state.total + length(rows),
         status_4xx: state.status_4xx + delta_4xx,
         status_5xx: state.status_5xx + delta_5xx
     }}
  end

  @impl true
  def handle_call(:snapshot, _from, state), do: {:reply, state, state}

  defp status_family(row) do
    code =
      Map.get(row, :status_code) ||
        Map.get(row, "status_code") ||
        Map.get(row, :status) ||
        Map.get(row, "status")

    with value when not is_nil(value) <- code,
         {status_code, ""} <- Integer.parse(to_string(value)) do
      cond do
        status_code in 400..499 -> :s4xx
        status_code >= 500 -> :s5xx
        true -> :other
      end
    else
      _ -> :other
    end
  end
end
