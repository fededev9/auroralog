defmodule AuraLog.Ingest.RateLimiterTest do
  use ExUnit.Case, async: false

  alias AuraLog.Ingest.RateLimiter

  setup do
    Application.put_env(:aura_log, :ingest_rate_limit_per_minute, 2)
    on_exit(fn -> Application.put_env(:aura_log, :ingest_rate_limit_per_minute, 3_000) end)
    :ok
  end

  test "returns rate_limited after threshold" do
    assert :ok = RateLimiter.allow?("tenant", "token-a", "127.0.0.1")
    assert :ok = RateLimiter.allow?("tenant", "token-a", "127.0.0.1")
    assert {:error, :rate_limited} = RateLimiter.allow?("tenant", "token-a", "127.0.0.1")
  end
end
