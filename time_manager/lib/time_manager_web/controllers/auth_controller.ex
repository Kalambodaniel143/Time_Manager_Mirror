defmodule TimeManagerWeb.AuthController do
  @moduledoc """
  Login, registration, current session and logout.

  At login the server generates a random CSRF token, signs a JWT that contains
  it (`TimeManager.Token`), puts the JWT in an HttpOnly cookie and returns the
  CSRF token in the response body, with the Session model of the organizations
  contract (`TimeManagerWeb.SessionJSON`). The front-end keeps the CSRF token
  and sends it in the `X-CSRF-Token` header; the browser sends the cookie on
  its own.
  """
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TimeManager.Accounts
  alias TimeManager.Email
  alias TimeManager.EmailDelivery
  alias TimeManager.Token
  alias TimeManagerWeb.Authz
  alias TimeManagerWeb.Plugs.{Authenticate, RateLimit}
  alias TimeManagerWeb.Schemas.{ErrorResponse, LoginRequest, RegisterRequest, SessionData}
  alias TimeManagerWeb.Schemas.{SessionResponse, UserResponse, ValidationErrorResponse}
  alias TimeManagerWeb.{SessionJSON, UserJSON}

  action_fallback TimeManagerWeb.FallbackController

  # Slows down password guessing: per account, and per address for spraying.
  plug RateLimit, [bucket: :login_email, limit: 10, by: :email] when action == :login
  plug RateLimit, [bucket: :login_ip, limit: 100] when action == :login
  plug RateLimit, [bucket: :register, limit: 20] when action == :register

  plug RateLimit,
       [bucket: :verify_email, limit: 20] when action in [:verify_email, :resend_verification]

  tags(["auth"])

  operation(:login,
    summary: "Log in",
    description:
      "Sets the HttpOnly `jwt` cookie and returns the CSRF token to send in X-CSRF-Token, " <>
        "with the session (role, user, organization). 429 after too many attempts.",
    security: [],
    request_body: {"Credentials", "application/json", LoginRequest},
    responses: [
      ok: {"Logged in", "application/json", SessionResponse},
      unauthorized: {"Invalid credentials", "application/json", ErrorResponse},
      too_many_requests: {"Too many attempts", "application/json", ErrorResponse}
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
        |> put_status(:unauthorized)
        |> json(%{errors: %{detail: "Invalid credentials"}})
    end
  end

  operation(:register,
    summary: "Create an account and log in",
    description:
      "Self-registration, outside any organization. The account always starts with the " <>
        "employee role. To join an organization, use POST /api/join-requests.",
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

    with {:ok, user} <- Accounts.create_user(attrs, "employee", nil, verify_email: false),
         {:ok, code} <- Accounts.issue_email_verification(user),
         :ok <- user.email |> Email.verification(code) |> EmailDelivery.send() do
      conn
      |> put_status(:accepted)
      |> json(%{data: %{email: user.email, verification_required: true}})
    else
      {:error, :email_delivery_failed} -> {:error, :service_unavailable}
      error -> error
    end
  end

  def register(_conn, _params), do: {:error, :bad_request}

  operation(:verify_email,
    summary: "Verify registration email",
    description: "Verifies the six-digit OTP and opens a session.",
    security: [],
    responses: [ok: {"Verified", "application/json", SessionResponse}]
  )

  def verify_email(conn, %{"email" => email, "code" => code}) do
    case Accounts.verify_email(email, code) do
      {:ok, user} -> start_session(conn, user, :ok)
      {:error, :expired_code} -> {:error, :expired_code}
      {:error, :too_many_attempts} -> {:error, :too_many_attempts}
      {:error, :invalid_code} -> {:error, :invalid_code}
    end
  end

  def verify_email(_conn, _params), do: {:error, :bad_request}

  operation(:resend_verification,
    summary: "Resend registration email",
    description: "Sends a new verification OTP to an unverified account.",
    security: [],
    responses: [ok: {"OTP sent", "application/json", ErrorResponse}]
  )

  def resend_verification(conn, %{"email" => email}) when is_binary(email) do
    normalized = String.trim(email) |> String.downcase()

    with {:ok, user} <- Accounts.find_unverified_user(normalized),
         {:ok, code} <- Accounts.issue_email_verification(user),
         :ok <- normalized |> Email.verification(code) |> EmailDelivery.send() do
      json(conn, %{data: %{verification_required: true}})
    else
      {:error, :email_delivery_failed} -> {:error, :service_unavailable}
      _ -> json(conn, %{data: %{verification_required: true}})
    end
  end

  def resend_verification(_conn, _params), do: {:error, :bad_request}

  operation(:me,
    summary: "Current user",
    responses: [
      ok: {"Current user", "application/json", UserResponse},
      unauthorized: {"Not logged in", "application/json", ErrorResponse}
    ]
  )

  def me(conn, _params) do
    json(conn, %{data: UserJSON.data(Authz.current_user(conn), true)})
  end

  operation(:session,
    summary: "Current session",
    description:
      "Role, user and organization, read from the database: a promotion shows at the next " <>
        "call. 401 when the session is missing, expired or revoked.",
    responses: [
      ok: {"Session", "application/json", SessionData},
      unauthorized: {"Not logged in", "application/json", ErrorResponse}
    ]
  )

  def session(conn, _params) do
    user = conn |> Authz.current_user() |> Accounts.preload_organization()
    json(conn, %{data: SessionJSON.data(user)})
  end

  operation(:logout,
    summary: "Log out",
    description: "Revokes the session's JWT on the server and removes the cookie.",
    responses: [no_content: "Session ended"]
  )

  def logout(conn, _params) do
    :ok = Accounts.revoke_session(conn.assigns.session_claims)

    conn
    |> delete_resp_cookie(Authenticate.cookie_name(), cookie_options())
    |> send_resp(:no_content, "")
  end

  @doc """
  Opens a session for `user`: sets the cookie and answers `status` with the
  Session model plus the CSRF token. Also used at organization creation.
  """
  def start_session(conn, user, status) do
    user = Accounts.preload_organization(user)
    csrf_token = Token.generate_csrf_token()
    {:ok, jwt, _claims} = Token.sign(user, csrf_token)

    conn
    |> put_resp_cookie(
      Authenticate.cookie_name(),
      jwt,
      cookie_options() ++ [max_age: Token.ttl_seconds()]
    )
    |> put_status(status)
    |> json(%{data: user |> SessionJSON.data() |> Map.put(:csrf_token, csrf_token)})
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
