defmodule TimeManagerWeb.Plugs.Authenticate do
  @moduledoc """
  Authenticates every protected request.

  The request must carry both:

    * the `jwt` cookie (HttpOnly, set at login, sent by the browser), and
    * the `X-CSRF-Token` header (set by the front-end from the login response).

  The JWT must be validly signed and not expired, and its `xsrf` claim must
  match the header. A third-party site can make the browser send the cookie,
  but cannot know the CSRF token, so it cannot forge a request.

  The user and their role are then read from the database, not from the
  token: a demotion or a deleted account takes effect on the next request.
  On success the user is assigned to `conn.assigns.current_user`; otherwise
  the request stops with 401.
  """
  import Plug.Conn

  alias TimeManager.Accounts
  alias TimeManager.Token

  @cookie "jwt"

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_cookies(conn)

    with jwt when is_binary(jwt) <- conn.req_cookies[@cookie],
         [csrf | _] <- get_req_header(conn, "x-csrf-token"),
         {:ok, claims} <- Token.verify_and_validate(jwt),
         xsrf when is_binary(xsrf) <- claims["xsrf"],
         true <- Plug.Crypto.secure_compare(csrf, xsrf),
         {:ok, user} <- Accounts.fetch_user(claims["user_id"]) do
      assign(conn, :current_user, user)
    else
      _ -> unauthorized(conn)
    end
  end

  def cookie_name, do: @cookie

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{errors: %{detail: "Unauthorized"}}))
    |> halt()
  end
end
