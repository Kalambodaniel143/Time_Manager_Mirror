defmodule TimeManagerWeb.Plugs.Authenticate do
  @moduledoc """
  Authenticates every protected request.

  Ordinary protected requests must carry both:

    * the `jwt` cookie (HttpOnly, set at login, sent by the browser), and
    * the `X-CSRF-Token` header (set by the front-end from the login response).

  The JWT must be validly signed, not expired and not revoked by a logout, and
  its `xsrf` claim must match the header. A third-party site can make the
  browser send the cookie, but cannot know the CSRF token, so it cannot forge a
  request.

  The read-only GET /api/auth/session route also permits X-Session-Restore: 1
  to recover the matching CSRF for a fresh tab. It still verifies the JWT and
  account, refuses cross-origin fetch metadata and never rotates the cookie.

  The user and their role are then read from the database, not from the
  token: a demotion or a deleted account takes effect on the next request.
  On success the user is assigned to `conn.assigns.current_user` (and the JWT
  claims to `conn.assigns.session_claims`, used by the logout); otherwise the
  request stops with 401.
  """
  import Plug.Conn

  alias TimeManager.Accounts
  alias TimeManager.Token

  @cookie "jwt"

  def init(opts), do: opts

  def call(conn, opts) do
    conn = fetch_cookies(conn)

    with jwt when is_binary(jwt) <- conn.req_cookies[@cookie],
         {:ok, claims} <- Token.verify_and_validate(jwt),
         xsrf when is_binary(xsrf) <- claims["xsrf"],
         true <- valid_csrf?(conn, xsrf) or session_restore?(conn, opts),
         false <- Accounts.session_revoked?(claims["jti"]),
         {:ok, user} <- Accounts.fetch_user(claims["user_id"]),
         true <- user.session_version == Map.get(claims, "session_version", 0) do
      conn
      |> assign(:current_user, user)
      |> assign(:session_claims, claims)
    else
      _ -> unauthorized(conn)
    end
  end

  def cookie_name, do: @cookie

  defp valid_csrf?(conn, xsrf) do
    case get_req_header(conn, "x-csrf-token") do
      [csrf | _] -> Plug.Crypto.secure_compare(csrf, xsrf)
      _ -> false
    end
  end

  # Only this read-only route can bootstrap a fresh tab. The custom header is
  # unavailable to cross-origin forms; the API grants no cross-origin CORS access.
  # JWT signature, expiry, revocation, user and session version are always checked.
  defp session_restore?(conn, opts) do
    Keyword.get(opts, :session_restore, false) and conn.method == "GET" and
      conn.request_path == "/api/auth/session" and
      get_req_header(conn, "x-session-restore") == ["1"] and
      get_req_header(conn, "sec-fetch-site") in [[], ["same-origin"], ["none"]]
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{errors: %{detail: "Unauthorized"}}))
    |> halt()
  end
end
