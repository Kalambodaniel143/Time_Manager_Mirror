defmodule TimeManagerWeb.Plugs.RateLimit do
  @moduledoc """
  Limits the number of requests per client in a time window, and answers 429
  with a `Retry-After` header beyond. Used on the public routes: login, account
  and organization creation, organization lookup, join requests.

      plug RateLimit, bucket: :login, limit: 10, period: :timer.minutes(1), by: :email

    * `by: :ip` (default) counts per client address;
    * `by: :email` counts per `email` parameter, so that guessing the password
      of one account is slowed down even from many addresses.

  L'adresse `conn.remote_ip` est corrigée uniquement par le proxy de confiance.

  It can be switched off with `config :time_manager, :rate_limit, false`
  (the test configuration does so; the tests of this plug turn it back on with
  `enabled: true`).
  """
  import Plug.Conn

  alias TimeManagerWeb.RateLimiter

  def init(opts) do
    %{
      bucket: Keyword.fetch!(opts, :bucket),
      limit: Keyword.fetch!(opts, :limit),
      period: Keyword.get(opts, :period, :timer.minutes(1)),
      by: Keyword.get(opts, :by, :ip),
      enabled: Keyword.get(opts, :enabled),
      writes_only: Keyword.get(opts, :writes_only, false)
    }
  end

  def call(conn, opts) do
    if enabled?(opts) and (not opts.writes_only or conn.method not in ~w(GET HEAD OPTIONS)) do
      key = {opts.bucket, identity(conn, opts.by)}

      case RateLimiter.hit(key, opts.limit, opts.period) do
        :ok -> conn
        {:error, retry_after} -> too_many_requests(conn, retry_after)
      end
    else
      conn
    end
  end

  defp enabled?(%{enabled: nil}), do: Application.get_env(:time_manager, :rate_limit, true)
  defp enabled?(%{enabled: enabled}), do: enabled

  defp identity(conn, :ip), do: conn.remote_ip
  defp identity(conn, :user), do: conn.assigns.current_user.id

  defp identity(conn, :email) do
    case conn.params["email"] do
      email when is_binary(email) and byte_size(email) <= 254 ->
        :crypto.hash(:sha256, email |> String.trim() |> String.downcase())

      _ ->
        nil
    end
  end

  defp too_many_requests(conn, retry_after) do
    conn
    |> put_resp_header("retry-after", Integer.to_string(retry_after))
    |> put_resp_content_type("application/json")
    |> send_resp(
      429,
      Jason.encode!(%{errors: %{detail: "Trop de tentatives. Réessayez dans quelques instants."}})
    )
    |> halt()
  end
end
