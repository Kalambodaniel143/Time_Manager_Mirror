defmodule TimeManagerWeb.UserController do
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import TimeManagerWeb.Authz

  alias TimeManager.Accounts
  alias TimeManager.Accounts.User
  alias TimeManager.Authorization
  alias TimeManagerWeb.Plugs.Authenticate

  alias TimeManagerWeb.Schemas.{
    AccountDeletionRequest,
    ErrorResponse,
    RoleRequest,
    UserRequest,
    UserResponse
  }

  alias TimeManagerWeb.Schemas.{UsersResponse, ValidationErrorResponse}

  action_fallback TimeManagerWeb.FallbackController

  # The only fields a profile form may change (mass assignment).
  @profile_fields ["username", "email", "first_name", "last_name"]

  tags(["users"])

  operation(:index,
    summary: "List users",
    description:
      "Administrators see their organization, managers see the members of the teams they " <>
        "manage (and themselves). Employees get 403.",
    parameters: [
      email: [in: :query, type: :string, required: false, description: "Filter by exact email"],
      username: [
        in: :query,
        type: :string,
        required: false,
        description: "Filter by exact username"
      ]
    ],
    responses: [
      ok: {"Users list", "application/json", UsersResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse}
    ]
  )

  def index(conn, params) do
    me = current_user(conn)

    case Authorization.user_scope(me) do
      :forbidden -> {:error, :forbidden}
      scope -> render(conn, :index, users: Accounts.list_users(params, scope), viewer: me)
    end
  end

  operation(:create,
    summary: "Create a user in the administrator's organization",
    request_body: {"User attributes", "application/json", UserRequest},
    responses: [
      created: {"User created", "application/json", UserResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse}
    ]
  )

  def create(conn, %{"user" => user_params}) when is_map(user_params) do
    me = current_user(conn)

    with :ok <- authorize(Authorization.administrator?(me)),
         {:ok, %User{} = user} <-
           Accounts.create_user(
             Map.take(user_params, @profile_fields ++ ["password"]),
             Map.get(user_params, "role", "employee"),
             me.organization_id
           ) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/users/#{user}")
      |> render(:show, user: user, viewer: me)
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}

  operation(:show,
    summary: "Get a user by ID",
    parameters: [
      id: [in: :path, type: :integer, description: "User ID", example: 1]
    ],
    responses: [
      ok: {"User", "application/json", UserResponse},
      forbidden: {"Outside the caller's scope", "application/json", ErrorResponse},
      not_found: {"User not found", "application/json", ErrorResponse}
    ]
  )

  def show(conn, %{"id" => id}) do
    me = current_user(conn)

    with {:ok, id} <- cast_id(id),
         :ok <- authorize(Authorization.can_view?(me, id)),
         {:ok, %User{} = user} <- Accounts.fetch_user(id) do
      render(conn, :show, user: user, viewer: me)
    end
  end

  operation(:update,
    summary: "Update a user",
    description:
      "Yourself or, for an administrator, anyone in their organization. Only username, " <>
        "email, first_name, last_name and password are read: the role has its own route.",
    parameters: [
      id: [in: :path, type: :integer, description: "User ID", example: 1]
    ],
    request_body: {"User attributes", "application/json", UserRequest},
    responses: [
      ok: {"User updated", "application/json", UserResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      not_found: {"User not found", "application/json", ErrorResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse}
    ]
  )

  def update(conn, %{"id" => id, "user" => user_params}) when is_map(user_params) do
    me = current_user(conn)

    with {:ok, id} <- cast_id(id),
         :ok <- authorize(Authorization.can_edit_profile?(me, id)),
         {:ok, %User{} = user} <- Accounts.fetch_user(id),
         {:ok, user} <-
           Accounts.update_account(
             user,
             Map.take(user_params, @profile_fields),
             password_change(me, user, user_params)
           ) do
      render(conn, :show, user: user, viewer: me)
    end
  end

  def update(_conn, _params), do: {:error, :bad_request}

  operation(:update_role,
    summary: "Promote or demote a user (administrator)",
    description:
      "Administrators of the user's organization only, never on themselves. The last " <>
        "administrator of an organization cannot be demoted. The new role applies from the " <>
        "user's next request.",
    parameters: [
      id: [in: :path, type: :integer, description: "User ID", example: 1]
    ],
    request_body: {"New role", "application/json", RoleRequest},
    responses: [
      ok: {"User updated", "application/json", UserResponse},
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      not_found: {"User not found", "application/json", ErrorResponse},
      conflict: {"Last administrator", "application/json", ErrorResponse},
      unprocessable_entity: {"Unknown role", "application/json", ValidationErrorResponse}
    ]
  )

  def update_role(conn, %{"id" => id, "role" => role}) do
    me = current_user(conn)

    with {:ok, id} <- cast_id(id),
         :ok <- authorize(Authorization.can_change_role?(me, id)),
         {:ok, %User{} = user} <- Accounts.fetch_user(id),
         {:ok, user} <- Accounts.change_role(user, role) do
      render(conn, :show, user: user, viewer: me)
    end
  end

  def update_role(_conn, _params), do: {:error, :bad_request}

  operation(:delete,
    summary: "Delete your own account or a user of your organization",
    description:
      "Self-deletion requires current_password. Administrators can delete another account " <>
        "in their organization without its password. Also deletes clocks and working times; " <>
        "the last administrator cannot be deleted.",
    request_body:
      {"Password confirmation for self-deletion", "application/json", AccountDeletionRequest,
       required: false},
    parameters: [
      id: [in: :path, type: :integer, description: "User ID", example: 1]
    ],
    responses: [
      no_content: "User deleted",
      forbidden: {"Not allowed", "application/json", ErrorResponse},
      not_found: {"User not found", "application/json", ErrorResponse},
      conflict: {"Last administrator", "application/json", ErrorResponse},
      unprocessable_entity:
        {"Incorrect or missing current password", "application/json", ValidationErrorResponse}
    ]
  )

  def delete(conn, %{"id" => id} = params) do
    actor = current_user(conn)

    with {:ok, id} <- cast_id(id),
         :ok <- authorize(Authorization.can_delete_account?(actor, id)),
         {:ok, %User{} = user} <- Accounts.fetch_user(id),
         :ok <- verify_deletion_password(actor, user, params["current_password"]),
         {:ok, %User{}} <- Accounts.delete_user(user) do
      conn =
        if actor.id == user.id do
          delete_resp_cookie(conn, Authenticate.cookie_name(),
            path: "/",
            http_only: true,
            same_site: "Strict",
            secure: Application.get_env(:time_manager, :auth_cookie_secure, false)
          )
        else
          conn
        end

      send_resp(conn, :no_content, "")
    end
  end

  defp verify_deletion_password(%User{id: id}, %User{id: id} = user, password) do
    if User.valid_password?(user, password) do
      :ok
    else
      {:error,
       user
       |> User.changeset(%{})
       |> Ecto.Changeset.add_error(:current_password, "is not valid")}
    end
  end

  defp verify_deletion_password(_actor, _user, _password), do: :ok

  # No password in the request: nothing to change. An administrator resets
  # someone else's password; anyone changing their own must give the current one.
  defp password_change(me, user, %{"password" => password} = params)
       when is_binary(password) and password != "" do
    if Authorization.administrator?(me) and me.id != user.id do
      {:reset, password}
    else
      {:change, params["current_password"], password}
    end
  end

  defp password_change(_me, _user, _params), do: :none
end
