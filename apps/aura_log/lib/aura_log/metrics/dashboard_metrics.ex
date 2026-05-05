defmodule AuraLog.Metrics.DashboardMetrics do
  @moduledoc """
  Composes snapshot metrics for realtime LiveView widgets.
  """

  alias AuraLog.Query.Service

  def snapshot do
    %{
      throughput: Service.throughput(),
      errors: Service.error_rates()
    }
  end
end
