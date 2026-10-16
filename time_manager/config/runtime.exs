import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/time_manager start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :time_manager, TimeManagerWeb.Endpoint, server: true
end

config :time_manager, TimeManagerWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

config :time_manager,
       :resend_from,
       System.get_env("RESEND_FROM", "Time Manager <onboarding@resend.dev>")

config :time_manager,
       :resend_from_email,
       System.get_env("RESEND_FROM_EMAIL", "onboarding@resend.dev")

email_delivery =
  case System.get_env("EMAIL_DELIVERY", if(config_env() == :prod, do: "resend", else: "mailpit")) do
    "mailpit" -> :mailpit
    "resend" -> :resend
    value -> raise "EMAIL_DELIVERY must be either mailpit or resend, got: #{value}"
  end

config :time_manager, :email_delivery, if(config_env() == :test, do: :test, else: email_delivery)

if email_delivery == :mailpit and config_env() != :test do
  config :time_manager, TimeManager.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: System.get_env("MAILPIT_HOST", "localhost"),
    port: String.to_integer(System.get_env("MAILPIT_PORT", "1025"))
end

# Anciennes clés publiques : elles ne doivent plus être utilisées.
public_secrets = [
  "dev-only-jwt-secret-do-not-use-in-production-0000",
  "U1l53a02xhNAUKkphogJq1VuG533+D4OGef2TOzxA0z95FN4KQVvdPbVIggAUKDj",
  "azfg0P/xPARZWOqu2eJ22UYgd1ojQgOF82ZlKpjtBnkOGeuQQnCYcx+6EuVGRymk"
]

required_secret! = fn name, minimum ->
  secret = System.get_env(name)

  unless is_binary(secret) and byte_size(secret) >= minimum and
           not String.match?(secret, ~r/\s/u) and secret not in public_secrets do
    raise "#{name} requise : clé privée sans espaces, au moins #{minimum} octets"
  end

  secret
end

# Aucun repli, même en développement ou dans les tests.
jwt_secret = required_secret!.("JWT_SECRET", 32)

config :joken, default_signer: jwt_secret

if config_env() == :prod do
  database_url = System.get_env("DATABASE_URL", "")

  # Valide l'URL sans inclure sa valeur (et son mot de passe) dans les erreurs.
  valid_database_url? =
    try do
      uri = URI.parse(database_url)
      options = Ecto.Repo.Supervisor.parse_url(database_url)

      uri.scheme in ["postgres", "postgresql"] and
        is_binary(uri.host) and uri.host != "" and
        is_binary(options[:username]) and options[:username] != "" and
        is_binary(options[:password]) and options[:password] != "" and
        is_binary(options[:database]) and options[:database] != "" and
        (is_nil(uri.port) or uri.port in 1..65_535) and
        is_nil(uri.fragment) and not String.match?(database_url, ~r/\s/u)
    rescue
      _ -> false
    end

  unless valid_database_url? do
    raise "DATABASE_URL requise : URL postgres://USER:PASSWORD@HOST:PORT/DATABASE valide"
  end

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :time_manager, TimeManager.Repo,
    # ssl: true,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base = required_secret!.("SECRET_KEY_BASE", 64)

  host = System.get_env("PHX_HOST", "")

  unless byte_size(host) in 1..253 and
           Regex.match?(~r/\A[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?\z/, host) and
           not String.contains?(host, "..") do
    raise "PHX_HOST requis : nom de domaine sans protocole, chemin ni port"
  end

  public_port = String.to_integer(System.get_env("PUBLIC_PORT", "80"))
  unless public_port in 1..65_535, do: raise("PUBLIC_PORT invalide")
  public_origin = URI.to_string(%URI{scheme: "http", host: host, port: public_port})
  config :time_manager, :public_origin, public_origin

  proxy = System.get_env("TRUSTED_PROXY_IP", "")

  case :inet.parse_address(String.to_charlist(proxy)) do
    {:ok, address} -> config :time_manager, :trusted_proxy_ip, address
    _ -> raise "TRUSTED_PROXY_IP requise : adresse IP du proxy interne"
  end

  if email_delivery == :resend do
    for name <- ["RESEND_API_KEY", "RESEND_FROM"] do
      if String.trim(System.get_env(name, "")) == "",
        do: raise("#{name} requise pour les courriels")
    end
  end

  config :time_manager, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :time_manager, TimeManagerWeb.Endpoint,
    url: [host: host, port: public_port, scheme: "http"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :time_manager, TimeManager.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://swoosh.hexdocs.pm/Swoosh.html#module-installation for details.
end
