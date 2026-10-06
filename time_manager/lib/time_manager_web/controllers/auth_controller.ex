defmodule TimeManagerWeb.AuthController do
  @moduledoc """
  Login, registration, current session and logout.

  At login the server generates a random CSRF token, signs a JWT that contains
  it (`TimeManager.Token`), puts the JWT in an HttpOnly cookie and returns the
  CSRF token in the response body. The front-end keeps the CSRF token and sends
  it in the `X-CSRF-Token` header; the browser sends the cookie on its own.
  """
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TimeManager.Accounts
  alias TimeManager.Token
  alias TimeManagerWeb.Authz
  alias TimeManagerWeb.Plugs.Authenticate
  alias TimeManagerWeb.Schemas.{ErrorResponse, LoginRequest, RegisterRequest}
  alias TimeManagerWeb.Schemas.{SessionResponse, UserResponse, ValidationErrorResponse}
  alias TimeManagerWeb.UserJSON

  action_fallback TimeManagerWeb.FallbackController

  tags(["auth"])

  operation(:login,
    summary: "Log in",
    description:
      "Sets the HttpOnly `jwt` cookie and returns the CSRF token to send in X-CSRF-Token.",
    security: [],
    request_body: {"Credentials", "application/json", LoginRequest},
    responses: [
      ok: {"Logged in", "application/json", SessionResponse},
      unauthorized: {"Invalid credentials", "application/json", ErrorResponse}
    ]
  )

  def login(conn, params) do
    case Accounts.authenticate(params["email"], params["password"]) do
      {:ok, user} ->
        start_session(conn, user, :ok)

      {:error, :invalid_credentials} ->
        # One message for unknown e-mail and wrong password: it must not reveal
        # which accounts exist.
        conn
        |> put_status(:unatuhorized)
        |> json(%{errors: %{detail: "Invalid credentials"}})
    end
  end

  operation(:register,
    summary: "Create an account and log in",
    description: "Self-registration. The account always starts with the employee role.",
    security: [],
    request_body: {"Account", "application/json", RegisterRequest},
    responses: [
      created: {"Account created", "application/json", SessionResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse}
    ]
  )

  def register(conn, %{"user" => attrs}) when is_map(attrs) do
    # Only these fields are read: a "role" sent by the client is ignored.
    attrs = Map.take(attrs, ["username", "email", "password"])

    with {:ok, user} <- Accounts.create_user(attrs, "employee") do
      start_session(conn, user, :created)
    end
  end

  def register(_conn, _params), do: {:error, :bad_request}

  operation(:me,
    summary: "Current user",
    responses: [
      ok: {"Current user", "application/json", UserResponse},
      unauthorized: {"Not logged in", "application/json", ErrorResponse}
    ]
  )

  def me(conn, _params) do
    json(conn, %{data: UserJSON.data(Authz.current_user(conn))})
  end

  operation(:logout,
    summary: "Log out",
    responses: [no_content: "Session cookie removed"]
  )

  def logout(conn, _params) do
    conn
    |> delete_resp_cookie(Authenticate.cookie_name(), cookie_options())
    |> send_resp(:no_content, "")
  end

  defp start_session(conn, user, status) do
    csrf_token = Token.generate_csrf_token()
    {:ok, jwt, _claims} = Token.sign(user, csrf_token)

    conn
    |> put_resp_cookie(
      Authenticate.cookie_name(),
      jwt,
      cookie_options() ++ [max_age: Token.ttl_seconds()]
    )
    |> put_status(status)
    |> json(%{data: %{csrf_token: csrf_token, user: UserJSON.data(user)}})
  end

  # HttpOnly: page scripts cannot read the JWT, so an XSS cannot steal it.
  # SameSite=Strict: the browser does not send it with requests from other sites.
  defp cookie_options do
    [
      http_only: true,
      same_site: "Strict",
      secure: Application.get_env(:time_manager, :auth_cookie_secure, false),
      path: "/"
    ]
  end
end
