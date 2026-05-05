defmodule AuraLog.Ingest.RateLimiter do
  @moduledoc """
  Fixed-window rate limiter keyed by `{tenant, token_hash, ip}`.
  """
  use GenServer

  @table __MODULE__

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def allow?(tenant, token, ip) when is_binary(tenant) and is_binary(token) and is_binary(ip) do
    limit = Application.get_env(:aura_log, :ingest_rate_limit_per_minute, 3_000)
    window = minute_window()
    key = {tenant, token_hash(token), ip, window}

    case :ets.update_counter(@table, key, {2, 1}, {key, 0}) do
      count when count <= limit -> :ok
      _ -> {:error, :rate_limited}
    end
  end

  @impl true
  def init(_state) do
    _ =
      :ets.new(@table, [
        :named_table,
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])

    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    current = minute_window()

    :ets.select_delete(
      @table,
      [{{{:_, :_, :_, :"$1"}, :_}, [{:<, :"$1", current - 1}], [true]}]
    )

    schedule_cleanup()
    {:noreply, state}
  end

  defp token_hash(token) do
    :crypto.hash(:sha256, token)
    |> Base.encode16(case: :lower)
  end

  defp minute_window, do: div(System.system_time(:second), 60)
  defp schedule_cleanup, do: Process.send_after(self(), :cleanup, 60_000)
end
