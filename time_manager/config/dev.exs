import Config

# Configure your database
config :time_manager, TimeManager.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  database: System.get_env("PGDATABASE", "time_manager_dev"),
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
config :time_manager, TimeManagerWeb.Endpoint,
  # Bound to all interfaces so the server is reachable from outside a
  # Docker container (and from other machines on the network).
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "U1l53a02xhNAUKkphogJq1VuG533+D4OGef2TOzxA0z95FN4KQVvdPbVIggAUKDj"

# Enable dev routes for dashboard and mailbox
config :time_manager, dev_routes: true

# Mailpit captures local OTP emails without sending them to real recipients.
config :time_manager, :email_delivery, :mailpit

config :time_manager, TimeManager.Mailer,
  adapter: Swoosh.Adapters.SMTP,
  relay: System.get_env("MAILPIT_HOST", "localhost"),
  port: String.to_integer(System.get_env("MAILPIT_PORT", "1025"))

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false
