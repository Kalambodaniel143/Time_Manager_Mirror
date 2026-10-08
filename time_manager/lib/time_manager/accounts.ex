defmodule TimeManager.Accounts do
  @moduledoc """
  The Accounts context: users, their password, their role and their sessions.

  Users returned by this module always have their role preloaded, so callers
  can read `user.role.name` directly.

  A user belongs to at most one organization. Users without one (created before
  organizations existed, or by self-registration) form their own space: for
  every check in this module and in `TimeManager.Authorization`, "the same
  organization" includes "both without organization".
  """

  import Ecto.Query, warn: false
  alias TimeManager.Repo

  alias TimeManager.Accounts.{EmailVerification, RevokedToken, Role, User}

  @default_role "employee"
  @verification_ttl 600
  @max_verification_attempts 5

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
  to `scope`: a list of ids, `{:organization, id}` (an organization, `nil` for
  users without one) or `:all` (no restriction).
  """
  def list_users(params, scope \\ :all) do
    User
    |> filter_by_scope(scope)
    |> filter_by_email(params["email"])
    |> filter_by_username(params["username"])
    |> order_by([u], asc: u.id)
    |> preload(:role)
    |> Repo.all()
  end

  defp filter_by_scope(query, :all), do: query
  defp filter_by_scope(query, {:organization, id}), do: in_organization(query, id)
  defp filter_by_scope(query, ids) when is_list(ids), do: from(u in query, where: u.id in ^ids)

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

  @doc "The members of an organization, by id."
  def list_organization_members(organization_id) do
    User
    |> in_organization(organization_id)
    |> order_by([u], asc: u.id)
    |> preload(:role)
    |> Repo.all()
  end

  @doc "Fetches the user `id` only if they belong to the organization."
  def fetch_organization_member(organization_id, id) do
    with {:ok, %User{organization_id: ^organization_id} = user} <- fetch_user(id) do
      {:ok, user}
    else
      _ -> {:error, :not_found}
    end
  end

  @doc """
  True when the user `id` exists and belongs to the organization
  `organization_id` (`nil`: has no organization).
  """
  def in_organization?(id, organization_id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} ->
        from(u in User, where: u.id == ^id) |> in_organization(organization_id) |> Repo.exists?()

      :error ->
        false
    end
  end

  @doc "Loads the organization of `user` (nil when they have none)."
  def preload_organization(%User{} = user), do: Repo.preload(user, :organization)

  ## Authentication

  @doc """
  Checks an e-mail and password pair.

  Unknown e-mail and wrong password give the same result, in the same time, so
  the answer does not reveal which accounts exist. A bcrypt hash from before the
  switch to Argon2id is replaced now that the password is known.
  """
  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email |> String.trim() |> String.downcase())

    if User.valid_password?(user, password) and User.verified?(user) do
      {:ok, user |> upgrade_hash(password) |> Repo.preload(:role)}
    else
      {:error, :invalid_credentials}
    end
  end

  def authenticate(_email, _password) do
    User.valid_password?(nil, nil)
    {:error, :invalid_credentials}
  end

  defp upgrade_hash(user, password) do
    with true <- User.legacy_hash?(user),
         {:ok, user} <- user |> User.rehash_changeset(password) |> Repo.update() do
      user
    else
      _ -> user
    end
  end

  ## Sessions

  @doc """
  Ends a session before its expiry: its `jti` is recorded until the JWT would
  have expired. Expired entries are purged at the same time.
  """
  def revoke_session(%{"jti" => jti, "exp" => exp}) when is_binary(jti) and is_integer(exp) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    from(t in RevokedToken, where: t.expires_at < ^now) |> Repo.delete_all()

    Repo.insert_all(RevokedToken, [%{jti: jti, expires_at: DateTime.from_unix!(exp)}],
      on_conflict: :nothing
    )

    :ok
  end

  def revoke_session(_claims), do: :ok

  def session_revoked?(jti) when is_binary(jti),
    do: Repo.exists?(from t in RevokedToken, where: t.jti == ^jti)

  def session_revoked?(_jti), do: true

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
  def create_user(attrs, role_name \\ @default_role, organization_id \\ nil, opts \\ []) do
    case get_role_by_name(role_name) do
      nil ->
        {:error, role_error(%User{}, attrs)}

      role ->
        %User{}
        |> User.registration_changeset(attrs, role.id, organization_id)
        |> maybe_verify_email(opts)
        |> Repo.insert()
        |> preload_role()
    end
  end

  defp maybe_verify_email(changeset, opts) do
    if Keyword.get(opts, :verify_email, true) do
      Ecto.Changeset.put_change(
        changeset,
        :email_verified_at,
        DateTime.utc_now() |> DateTime.truncate(:second)
      )
    else
      changeset
    end
  end

  def issue_email_verification(%User{} = user) do
    code =
      :crypto.strong_rand_bytes(4)
      |> :binary.decode_unsigned()
      |> rem(1_000_000)
      |> Integer.to_string()
      |> String.pad_leading(6, "0")

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    verification = %{
      user_id: user.id,
      code_hash: hash_code(code),
      expires_at: DateTime.add(now, @verification_ttl, :second),
      attempts: 0,
      inserted_at: now,
      updated_at: now
    }

    Repo.insert_all(EmailVerification, [verification],
      on_conflict: {:replace, [:code_hash, :expires_at, :attempts, :updated_at]},
      conflict_target: :user_id
    )

    {:ok, code}
  end

  def find_unverified_user(email) when is_binary(email) do
    case Repo.get_by(User, email: email) do
      %User{} = user when is_nil(user.email_verified_at) -> {:ok, user}
      _ -> {:error, :not_found}
    end
  end

  def verify_email(email, code) when is_binary(email) and is_binary(code) do
    user = Repo.get_by(User, email: email |> String.trim() |> String.downcase())
    verification = user && Repo.get_by(EmailVerification, user_id: user.id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    cond do
      is_nil(user) or is_nil(verification) ->
        {:error, :invalid_code}

      DateTime.compare(verification.expires_at, now) == :lt ->
        {:error, :expired_code}

      verification.attempts >= @max_verification_attempts ->
        {:error, :too_many_attempts}

      not Plug.Crypto.secure_compare(verification.code_hash, hash_code(code)) ->
        Repo.update_all(
          from(v in EmailVerification, where: v.id == ^verification.id),
          inc: [attempts: 1]
        )

        {:error, :invalid_code}

      true ->
        user = user |> Ecto.Changeset.change(email_verified_at: now) |> Repo.update!()
        Repo.delete!(verification)
        {:ok, Repo.preload(user, :role)}
    end
  end

  defp hash_code(code), do: :crypto.hash(:sha256, code) |> Base.encode16(case: :lower)

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
  Promotes or demotes a user. The last administrator of an organization cannot
  be demoted, so it always keeps someone able to manage it.
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
  administrator of an organization cannot be deleted.

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

  defp ensure_not_last_admin(%User{role: %Role{name: "administrator"}} = user, new_role)
       when new_role != "administrator" do
    admins =
      from(u in User, join: r in assoc(u, :role), where: r.name == "administrator")
      |> in_organization(user.organization_id)
      |> Repo.aggregate(:count)

    if admins > 1, do: :ok, else: {:error, :last_administrator}
  end

  defp ensure_not_last_admin(_user, _new_role), do: :ok

  defp role_error(user, attrs) do
    user
    |> User.changeset(attrs)
    |> Ecto.Changeset.add_error(:role, "is invalid", validation: :inclusion, enum: Role.names())
  end

  defp in_organization(query, nil), do: from(u in query, where: is_nil(u.organization_id))
  defp in_organization(query, id), do: from(u in query, where: u.organization_id == ^id)

  defp preload_role(result, opts \\ [])
  defp preload_role({:ok, user}, opts), do: {:ok, Repo.preload(user, :role, opts)}
  defp preload_role(error, _opts), do: error
end
