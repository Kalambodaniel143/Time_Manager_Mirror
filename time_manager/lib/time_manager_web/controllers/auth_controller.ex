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
  plug RateLimit, [bucket: :login_ip, limit: 100] when action == :login
  plug RateLimit, [bucket: :login_email, limit: 10, by: :email] when action == :login
  plug RateLimit, [bucket: :register, limit: 20] when action == :register

  plug RateLimit,
       [bucket: :password_recovery_email, limit: 5, by: :email] when action == :forgot_password

  plug RateLimit, [bucket: :password_recovery_ip, limit: 50] when action == :forgot_password

  plug RateLimit,
       [bucket: :password_reset_email, limit: 10, by: :email] when action == :reset_password

  plug RateLimit, [bucket: :password_reset_ip, limit: 100] when action == :reset_password

  plug RateLimit,
       [bucket: :verify_email, limit: 20] when action in [:verify_email, :resend_verification]

  tags(["auth"])

  operation(:forgot_password,
    summary: "Send a password recovery code",
    security: [],
    request_body:
      {"Email address", "application/json", TimeManagerWeb.Schemas.PasswordRecoveryRequest},
    responses: [
      accepted:
        {"Same reply for known and unknown accounts", "application/json",
         TimeManagerWeb.Schemas.WorkflowResponse},
      bad_request: {"Missing or malformed fields", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid email", "application/json", ErrorResponse},
      too_many_requests: {"Rate limit", "application/json", ErrorResponse}
    ]
  )

  def forgot_password(conn, %{"email" => email}) when is_binary(email) do
    if String.length(email) <= 254 and
         Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, String.trim(email)) do
      with :ok <- TimeManager.Accounts.PasswordRecovery.request(email) do
        conn
        |> put_status(:accepted)
        |> json(%{
          data: %{
            message:
              "Si un compte actif correspond à cette adresse, un code vous sera envoyé. Vérifiez votre boîte mail et vos courriers indésirables. Le code expire dans 15 minutes."
          }
        })
      end
    else
      {:error,
       {:unprocessable_entity, "Saisissez une adresse email valide, par exemple nom@domaine.fr."}}
    end
  end

  def forgot_password(_, _), do: {:error, :bad_request}

  operation(:reset_password,
    summary: "Reset a password with a one-use eight-digit code; revoke all old sessions",
    security: [],
    request_body:
      {"Email, code and new password", "application/json",
       TimeManagerWeb.Schemas.PasswordResetRequest},
    responses: [
      ok: {"Password reset", "application/json", TimeManagerWeb.Schemas.WorkflowResponse},
      bad_request: {"Missing or malformed fields", "application/json", ErrorResponse},
      unprocessable_entity: {"Invalid code or weak password", "application/json", ErrorResponse},
      too_many_requests: {"Rate limit", "application/json", ErrorResponse}
    ]
  )

  def reset_password(conn, %{"email" => email, "code" => code, "password" => password})
      when is_binary(email) and is_binary(code) and is_binary(password) do
    with :ok <- TimeManager.Accounts.PasswordRecovery.complete(email, String.trim(code), password) do
      json(conn, %{
        data: %{
          message: "Mot de passe réinitialisé. Connectez-vous avec votre nouveau mot de passe."
        }
      })
    end
  end

  def reset_password(_, _), do: {:error, :bad_request}

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
        "call. A new tab may use X-Session-Restore: 1 with its valid JWT cookie to recover " <>
        "the session-bound CSRF token. Read-only, no cookie rotation. " <>
        "401 when the session is missing, expired or revoked.",
    parameters: [
      "X-Session-Restore": [
        in: :header,
        type: :string,
        description: "1 for read-only restoration"
      ]
    ],
    security: [
      %{"jwtCookie" => [], "csrfToken" => []},
      %{"jwtCookie" => [], "sessionRestoreHeader" => []}
    ],
    responses: [
      ok: {"Session", "application/json", SessionData},
      unauthorized: {"Not logged in", "application/json", ErrorResponse}
    ]
  )

  def session(conn, _params) do
    user = conn |> Authz.current_user() |> Accounts.preload_organization()

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("vary", "Cookie")
    |> json(%{
      data: Map.put(SessionJSON.data(user), :csrf_token, conn.assigns.session_claims["xsrf"])
    })
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
      path: "/"
    ]
  end
end
