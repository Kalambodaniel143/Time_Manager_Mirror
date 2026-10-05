defmodule TimeManager.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  # The subject asks for X@X.X: something, an @, something, a dot, something.
  @email_format ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/
  @min_password_length 8

  schema "users" do
    field :username, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true

    belongs_to :role, TimeManager.Accounts.Role
    has_many :working_times, TimeManager.WorkingTimes.WorkingTime
    has_many :clocks, TimeManager.Clocks.Clock

    many_to_many :teams, TimeManager.Teams.Team, join_through: "team_members"

    timestamps(type: :utc_datetime)
  end

  @doc """
  Profile fields only. The role and the password have their own changesets, so a
  profile form can never change them (mass assignment).
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email])
    |> validate_required([:username, :email])
    |> validate_email()
  end

  @doc "A new account: profile, mandatory password and role."
  def registration_changeset(user, attrs, role_id) do
    user
    |> changeset(attrs)
    |> put_change(:role_id, role_id)
    |> password_changeset(attrs)
  end

  @doc "Sets a new password and stores only its bcrypt hash."
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: @min_password_length, max: 72)
    |> hash_password()
  end

  def role_changeset(user, role_id) do
    user
    |> change(role_id: role_id)
    |> foreign_key_constraint(:role_id)
  end

  @doc "Checks a password against the stored hash, in constant time."
  def valid_password?(%__MODULE__{password_hash: hash}, password)
      when is_binary(hash) and is_binary(password) do
    Bcrypt.verify_pass(password, hash)
  end

  def valid_password?(_user, _password) do
    # Same cost as a real check, so response time does not reveal unknown e-mails.
    Bcrypt.no_user_verify()
    false
  end

  defp validate_email(changeset) do
    changeset
    |> update_change(:email, &String.downcase/1)
    |> validate_format(:email, @email_format, message: "must look like name@domain.tld")
    |> validate_length(:email, max: 160)
    |> unique_constraint(:email, name: :users_email_index)
  end

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    changeset
    |> put_change(:password_hash, Bcrypt.hash_pwd_salt(password))
    |> delete_change(:password)
  end

  defp hash_password(changeset), do: changeset
end
