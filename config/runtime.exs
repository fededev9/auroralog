import Config

if config_env() == :prod do
  ingest_jwt_secret =
    System.get_env("AURALOG_INGEST_JWT_SECRET") ||
      raise """
      environment variable AURALOG_INGEST_JWT_SECRET is missing.
      Generate one and set it before starting the release.
      """

  udp_ingest? =
    case System.get_env("AURALOG_UDP_INGEST_ENABLED", "false")
         |> String.trim()
         |> String.downcase() do
      "1" -> true
      "true" -> true
      "yes" -> true
      _ -> false
    end

  config :aura_log, :start_udp_listener, udp_ingest?

  if udp_ingest? do
    udp_token =
      System.get_env("AURALOG_UDP_INGEST_TOKEN") ||
        raise """
        AURALOG_UDP_INGEST_TOKEN is required when AURALOG_UDP_INGEST_ENABLED=true.
        UDP payloads must be JSON: {"token":"...","tenant":"...","raw":"..."}
        """

    config :aura_log, :udp_ingest_token, udp_token
    config :aura_log, :udp_ingest_token_required, true
  end

  config :aura_log_web, AuraLogWeb.Endpoint,
    server: true,
    secret_key_base:
      System.get_env("SECRET_KEY_BASE") ||
        raise("""
        environment variable SECRET_KEY_BASE is missing.
        Generate one by running: mix phx.gen.secret
        """),
    http: [
      port: String.to_integer(System.get_env("PORT", "4000")),
      protocol_options: [idle_timeout: 60_000]
    ]

  config :aura_log, ingest_jwt_secret: ingest_jwt_secret
end
