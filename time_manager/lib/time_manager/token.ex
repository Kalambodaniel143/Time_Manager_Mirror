defmodule TimeManager.Token do
  @moduledoc """
  Session JWT, signed with HS256 by Joken. The signing key is `JWT_SECRET`
  (see config/runtime.exs).

  The token carries the user id, the role at login time and the CSRF token
  returned to the front-end. A JWT is signed, not encrypted: anyone can decode
  it, so it never holds a password or anything confidential.
  """
  use Joken.Config

  @ttl_seconds 8 * 60 * 60

  @impl true
  def token_config do
    default_claims(default_exp: @ttl_seconds, iss: "time_manager", aud: "time_manager")
  end

  def ttl_seconds, do: @ttl_seconds

  @doc "Builds a token for `user`, bound to `csrf_token`."
  def sign(user, csrf_token) do
    generate_and_sign(%{"user_id" => user.id, "role" => user.role.name, "xsrf" => csrf_token})
  end

  @doc "A random CSRF token: 32 bytes, URL-safe Base64."
  def generate_csrf_token do
    32 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end
