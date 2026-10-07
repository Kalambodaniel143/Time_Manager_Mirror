defmodule TimeManager.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias TimeManager.Accounts.Profile

  @min_password_length 8
  @max_password_length 128

  schema "users" do
    field :username, :string
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :gender, :string
    field :birth_date, :date
    field :birth_place, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true

    belongs_to :role, TimeManager.Accounts.Role
    belongs_to :organization, TimeManager.Organizations.Organization, type: :binary_id
    has_many :working_times, TimeManager.WorkingTimes.WorkingTime
    has_many :clocks, TimeManager.Clocks.Clock

    many_to_many :teams, TimeManager.Teams.Team, join_through: "team_members"

    timestamps(type: :utc_datetime)
  end

  @doc """
  Profile fields only. The role, the organization and the password have their
  own changesets, so a profile form can never change them (mass assignment).
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :first_name, :last_name])
    |> validate_required([:username, :email])
    |> update_change(:first_name, &String.trim/1)
    |> update_change(:last_name, &String.trim/1)
    |> validate_length(:first_name, max: 100)
    |> validate_length(:last_name, max: 100)
    |> validate_email()
  end

  @doc "A new account: profile, mandatory password, role and organization (if any)."
  def registration_changeset(user, attrs, role_id, organization_id \\ nil) do
    user
    |> changeset(attrs)
    |> put_change(:role_id, role_id)
    |> put_change(:organization_id, organization_id)
    |> password_changeset(attrs)
  end

  @doc """
  A member of an organization, created with its organization or when a join
  request is approved. The username is the e-mail, as the front-end expects.
  Personal details (gender, birth date and place) are only required with
  `personal_details: true`: the creator of an organization does not give them.
  """
  def member_changeset(user, profile, password, role_id, organization_id, opts \\ []) do
    personal? = Keyword.get(opts, :personal_details, true)
    fields = Profile.identity_fields() ++ if(personal?, do: Profile.personal_fields(), else: [])

    user
    |> cast(profile, fields)
    |> Profile.validate_identity()
    |> then(&if(personal?, do: Profile.validate_personal_details(&1), else: &1))
    |> then(&put_change(&1, :username, get_field(&1, :email)))
    |> unique_constraint(:email, name: :users_email_index)
    |> put_change(:role_id, role_id)
    |> put_change(:organization_id, organization_id)
    |> password_changeset(%{"password" => password})
  end

  @doc """
  Sets a new password and stores only its Argon2id hash. The password is kept
  as typed: never trimmed nor truncated. `validate_required` already refuses a
  password made of spaces only.
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: @min_password_length, max: @max_password_length)
    |> hash_password()
  end

  def role_changeset(user, role_id) do
    user
    |> change(role_id: role_id)
    |> foreign_key_constraint(:role_id)
  end

  @doc """
  Checks a password against the stored hash, in constant time. Hashes made
  before the switch to Argon2id are bcrypt hashes (`$2b$...`): they are still
  checked, then replaced at the next successful login (`legacy_hash?/1`).
  """
  def valid_password?(%__MODULE__{password_hash: "$2" <> _ = hash}, password)
      when is_binary(password) do
    Bcrypt.verify_pass(password, hash)
  end

  def valid_password?(%__MODULE__{password_hash: hash}, password)
      when is_binary(hash) and is_binary(password) do
    Argon2.verify_pass(password, hash)
  end

  def valid_password?(_user, _password) do
    # Same cost as a real check, so response time does not reveal unknown e-mails.
    Argon2.no_user_verify()
    false
  end

  @doc "True for a bcrypt hash, to be replaced by an Argon2id one."
  def legacy_hash?(%__MODULE__{password_hash: "$2" <> _}), do: true
  def legacy_hash?(_user), do: false

  @doc "Replaces the stored hash with a new one of `password` (already checked)."
  def rehash_changeset(user, password) do
    change(user, password_hash: Argon2.hash_pwd_salt(password))
  end

  defp validate_email(changeset) do
    changeset
    |> Profile.validate_email()
    |> unique_constraint(:email, name: :users_email_index)
  end

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    changeset
    |> put_change(:password_hash, Argon2.hash_pwd_salt(password))
    |> delete_change(:password)
  end

  defp hash_password(changeset), do: changeset
end
