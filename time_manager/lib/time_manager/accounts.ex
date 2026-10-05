defmodule TimeManager.Accounts do
  @moduledoc """
  The Accounts context: users, their password and their role.

  Users returned by this module always have their role preloaded, so callers
  can read `user.role.name` directly.
  """

  import Ecto.Query, warn: false
  alias TimeManager.Repo

  alias TimeManager.Accounts.{Role, User}

  @default_role "employee"

  ## Roles

  @doc "Lists the predefined roles, from the least to the most privileged."
  def list_roles do
    order = Role.names()

    Role
    |> Repo.all()
    |> Enum.sort_by(&Enum.find_index(order, fn name -> name == &1.name end))
  end

  def get_role_by_name(name) when is_binary(name), do: Repo.get_by(Role, name: name)
  def get_role_by_name(_name), do: nil

  ## Reading users

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    User |> preload(:role) |> Repo.all()
  end

  @doc """
  Lists users, optionally filtered by exact `email` and `username`, and restricted
  to the given `ids` when it is a list (`:all` means no restriction).
  """
  def list_users(params, ids \\ :all) do
    User
    |> filter_by_ids(ids)
    |> filter_by_email(params["email"])
    |> filter_by_username(params["username"])
    |> order_by([u], asc: u.id)
    |> preload(:role)
    |> Repo.all()
  end

  defp filter_by_ids(query, :all), do: query
  defp filter_by_ids(query, ids), do: from(u in query, where: u.id in ^ids)

  defp filter_by_email(query, nil), do: query

  defp filter_by_email(query, email) do
    from u in query, where: u.email == ^String.downcase(email)
  end

  defp filter_by_username(query, nil), do: query

  defp filter_by_username(query, username) do
    from u in query, where: u.username == ^username
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: User |> Repo.get!(id) |> Repo.preload(:role)

  @doc """
  Fetches a single user without raising.

  Returns `{:ok, user}` if `id` is a valid, existing user id, or
  `{:error, :not_found}` otherwise (including when `id` isn't a valid integer).

  ## Examples

      iex> fetch_user(123)
      {:ok, %User{}}

      iex> fetch_user(456)
      {:error, :not_found}

  """
  def fetch_user(id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} ->
        case Repo.get(User, id) do
          nil -> {:error, :not_found}
          user -> {:ok, Repo.preload(user, :role)}
        end

      :error ->
        {:error, :not_found}
    end
  end

  ## Authentication

  @doc """
  Checks an e-mail and password pair.

  Unknown e-mail and wrong password give the same result, in the same time, so
  the answer does not reveal which accounts exist.
  """
  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: String.downcase(email))

    if User.valid_password?(user, password) do
      {:ok, Repo.preload(user, :role)}
    else
      {:error, :invalid_credentials}
    end
  end

  def authenticate(_email, _password) do
    User.valid_password?(nil, nil)
    {:error, :invalid_credentials}
  end

  ## Writing users

  @doc """
  Creates a user with a password. The role defaults to employee; only an
  administrator should be allowed to pass another one.

  ## Examples

      iex> create_user(%{username: "alice", email: "alice@example.com", password: "..."})
      {:ok, %User{}}

      iex> create_user(%{username: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs, role_name \\ @default_role) do
    case get_role_by_name(role_name) do
      nil ->
        {:error, role_error(%User{}, attrs)}

      role ->
        %User{}
        |> User.registration_changeset(attrs, role.id)
        |> Repo.insert()
        |> preload_role()
    end
  end

  @doc """
  Updates the profile fields (username, email).

  ## Examples

      iex> update_user(user, %{username: "new"})
      {:ok, %User{}}

      iex> update_user(user, %{email: "bad"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
    |> preload_role()
  end

  @doc """
  Updates the profile and, in the same transaction, the password: either both
  are saved or neither is.

  `password_change` is `:none`, `{:reset, new}` (administrator, no check) or
  `{:change, current, new}` (the user, who must give the current password).
  """
  def update_account(%User{} = user, profile_attrs, password_change \\ :none) do
    Repo.transact(fn ->
      with {:ok, user} <- update_user(user, profile_attrs) do
        apply_password_change(user, password_change)
      end
    end)
  end

  defp apply_password_change(user, :none), do: {:ok, user}
  defp apply_password_change(user, {:reset, new}), do: reset_password(user, %{"password" => new})

  defp apply_password_change(user, {:change, current, new}),
    do: change_password(user, current, %{"password" => new})

  @doc """
  Changes the user's own password. The current password is required, so a
  stolen session alone is not enough to take over the account.
  """
  def change_password(%User{} = user, current_password, attrs) do
    if User.valid_password?(user, current_password) do
      reset_password(user, attrs)
    else
      changeset =
        user
        |> Ecto.Changeset.change()
        |> Ecto.Changeset.add_error(:current_password, "is not valid")

      {:error, changeset}
    end
  end

  @doc "Sets a new password without checking the old one (administrator reset)."
  def reset_password(%User{} = user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> Repo.update()
    |> preload_role()
  end

  @doc """
  Promotes or demotes a user. The last administrator cannot be demoted, so the
  application always keeps someone able to manage it.
  """
  def change_role(%User{} = user, role_name) do
    user = Repo.preload(user, :role)

    with %Role{} = role <- get_role_by_name(role_name) || {:error, role_error(user, %{})},
         :ok <- ensure_not_last_admin(user, role.name) do
      user
      |> User.role_changeset(role.id)
      |> Repo.update()
      |> preload_role(force: true)
    end
  end

  @doc """
  Deletes a user, with their clock events and working times. The last
  administrator cannot be deleted.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

  """
  def delete_user(%User{} = user) do
    with :ok <- ensure_not_last_admin(Repo.preload(user, :role), nil) do
      Repo.delete(user)
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  defp ensure_not_last_admin(%User{role: %Role{name: "administrator"}}, new_role)
       when new_role != "administrator" do
    admins =
      from(u in User, join: r in assoc(u, :role), where: r.name == "administrator")
      |> Repo.aggregate(:count)

    if admins > 1, do: :ok, else: {:error, :last_administrator}
  end

  defp ensure_not_last_admin(_user, _new_role), do: :ok

  defp role_error(user, attrs) do
    user
    |> User.changeset(attrs)
    |> Ecto.Changeset.add_error(:role, "is invalid", validation: :inclusion, enum: Role.names())
  end

  defp preload_role(result, opts \\ [])
  defp preload_role({:ok, user}, opts), do: {:ok, Repo.preload(user, :role, opts)}
  defp preload_role(error, _opts), do: error
end
