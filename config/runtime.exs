import Config

if config_env() == :prod do
  ingest_jwt_secret =
    System.get_env("AURALOG_INGEST_JWT_SECRET") ||
      raise """
      environment variable AURALOG_INGEST_JWT_SECRET is missing.
      Generate one and set it before starting the release.
      """

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
