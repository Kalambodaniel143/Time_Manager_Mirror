defmodule TimeManagerWeb.UserController do
  use TimeManagerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias TimeManager.Accounts
  alias TimeManager.Accounts.User
  alias TimeManagerWeb.Schemas.{ErrorResponse, UserRequest, UserResponse, UsersResponse}
  alias TimeManagerWeb.Schemas.ValidationErrorResponse

  action_fallback TimeManagerWeb.FallbackController

  tags(["users"])

  operation(:index,
    summary: "List users",
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
      ok: {"Users list", "application/json", UsersResponse}
    ]
  )

  def index(conn, params) do
    users = Accounts.list_users(params)
    json(conn, %{data: Enum.map(users, &user_to_json/1)})
  end

  operation(:create,
    summary: "Create a user",
    request_body: {"User attributes", "application/json", UserRequest},
    responses: [
      created: {"User created", "application/json", UserResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse}
    ]
  )

  def create(conn, %{"user" => user_params}) do
    with {:ok, %User{} = user} <- Accounts.create_user(user_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/users/#{user}")
      |> render(:show, user: user)
    end
  end

  operation(:show,
    summary: "Get a user by ID",
    parameters: [
      id: [in: :path, type: :integer, description: "User ID", example: 1]
    ],
    responses: [
      ok: {"User", "application/json", UserResponse},
      not_found: {"User not found", "application/json", ErrorResponse}
    ]
  )

  def show(conn, %{"id" => id}) do
    case Accounts.fetch_user(id) do
      {:ok, %User{} = user} ->
        json(conn, %{data: user_to_json(user)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
    end
  end

  # def update(conn, %{"id" => id, "user" => user_params}) do
  #   with {:ok, %User{} = user} <- Accounts.fetch_user(id), {:ok, %User{} = updated_user} <- Accounts.update_ser(user, user_parames) do
  #     json(conn, %{data: user_to_json(updated_user)})
  #   else
  #     {:error, :not_found} ->
  #       conn
  #       |>put_status(:not_found)
  #       |> json(%{error: "user not found"})
  #   end
  # end

  operation(:update,
    summary: "Update a user",
    parameters: [
      id: [in: :path, type: :integer, description: "User ID", example: 1]
    ],
    request_body: {"User attributes", "application/json", UserRequest},
    responses: [
      ok: {"User updated", "application/json", UserResponse},
      not_found: {"User not found", "application/json", ErrorResponse},
      unprocessable_entity: {"Validation errors", "application/json", ValidationErrorResponse}
    ]
  )

  def update(conn, %{"id" => id, "user" => user_params}) do
    with {:ok, %User{} = user} <- Accounts.fetch_user(id),
         {:ok, %User{} = updated_user} <- Accounts.update_user(user, user_params) do
      json(conn, %{data: user_to_json(updated_user)})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Utilisateur non trouvé"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  operation(:delete,
    summary: "Delete a user",
    parameters: [
      id: [in: :path, type: :integer, description: "User ID", example: 1]
    ],
    responses: [
      no_content: "User deleted",
      not_found: {"User not found", "application/json", ErrorResponse}
    ]
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, %User{} = user} <- Accounts.fetch_user(id),
         {:ok, %User{}} <- Accounts.delete_user(user) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Utilisateur non trouvé"})

      {:error, _reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Impossible de supprimer l'utilisateur"})
    end
  end

  defp user_to_json(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      username: user.username,
      inserted_at: user.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
