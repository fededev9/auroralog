defmodule AuraLogWeb.DashboardLive do
  use AuraLogWeb, :live_view

  alias AuraLog.Metrics.DashboardMetrics
  alias AuraLog.Query.Service

  @refresh_ms 1_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(AuraLog.PubSub, "dashboard:metrics")
      :timer.send_interval(@refresh_ms, :tick)
    end

    {:ok,
     socket
     |> assign(:snapshot, DashboardMetrics.snapshot())
     |> assign(:logs_per_sec, [])
     |> assign(:query, "")
     |> assign(:results, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    query = Map.get(params, "q", "")

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:results, search_results(query))}
  end

  @impl true
  def handle_info({:ingest_stats, payload}, socket) do
    rate =
      payload[:rows_written] || payload["rows_written"] || payload[:rows] || payload["rows"] || 0

    chart_points = update_rate_series(socket.assigns.logs_per_sec, rate)

    {:noreply,
     socket
     |> assign(:snapshot, DashboardMetrics.snapshot())
     |> assign(:logs_per_sec, chart_points)}
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply, assign(socket, :snapshot, DashboardMetrics.snapshot())}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    destination = "/dashboard?q=#{URI.encode_www_form(query)}#search-results"
    {:noreply, push_patch(socket, to: destination)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="al-dashboard">
        <h1>AuraLog Dashboard</h1>

        <div class="al-kpi-grid">
          <article class="al-panel">
            <h2>Throughput</h2>
            <p><%= @snapshot.throughput.total %> events</p>
          </article>
          <article class="al-panel">
            <h2>Error 4xx</h2>
            <p><%= @snapshot.errors.status_4xx %></p>
          </article>
          <article class="al-panel">
            <h2>Error 5xx</h2>
            <p><%= @snapshot.errors.status_5xx %></p>
          </article>
        </div>

        <article class="al-panel al-chart">
          <h2>Logs / sec (rolling)</h2>
          <svg viewBox="0 0 420 120" width="420" height="120" role="img" aria-label="Logs per second">
            <polyline
              fill="none"
              stroke="#60a5fa"
              stroke-width="3"
              points={svg_points(@logs_per_sec)}
            />
          </svg>
        </article>

        <section class="al-panel al-search">
          <form phx-submit="search">
            <input type="text" name="q" value={@query} placeholder="Search logs (service, message, status)" />
            <button type="submit">Search</button>
          </form>
        </section>

        <section id="search-results" class="al-panel al-results">
          <h2>Search Results</h2>
          <ul>
            <%= for row <- @results do %>
              <li>
                <strong><%= row[:service] || row["service"] || "unknown" %></strong>
                <span><%= row[:message] || row["message"] || row[:raw] || "" %></span>
              </li>
            <% end %>
          </ul>
        </section>
      </section>
    </Layouts.app>
    """
  end

  defp update_rate_series(series, value) do
    series
    |> Kernel.++([value])
    |> Enum.take(-30)
  end

  defp svg_points([]), do: ""

  defp svg_points(series) do
    max_value = max(Enum.max(series), 1)
    step_x = 420 / max(length(series) - 1, 1)

    series
    |> Enum.with_index()
    |> Enum.map(fn {value, idx} ->
      x = Float.round(idx * step_x, 2)
      y = Float.round(110 - value * 100 / max_value, 2)
      "#{x},#{y}"
    end)
    |> Enum.join(" ")
  end

  defp search_results(query), do: Service.search(query, limit: 100)
end
