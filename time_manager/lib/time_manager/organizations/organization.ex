defmodule TimeManager.Organizations.Organization do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "organizations" do
    field :name, :string
    field :normalized_name, :string

    has_many :users, TimeManager.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  The name is trimmed and its successive spaces reduced to one. Its normalized
  form is unique: two names that differ only by case, accents or spaces are
  the same organization.
  """
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name])
    |> update_change(:name, &squish/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 100)
    |> then(&put_change(&1, :normalized_name, normalize_name(get_field(&1, :name) || "")))
    |> unique_constraint(:name, name: :organizations_normalized_name_index)
  end

  @doc """
  The same normalization as the front-end (`normalizeName` in
  `src/utils/registration.js`): trimmed, single spaces, accents removed, lower case.
  """
  def normalize_name(name) when is_binary(name) do
    name
    |> squish()
    |> String.normalize(:nfd)
    |> String.replace(~r/[\x{0300}-\x{036f}]/u, "")
    |> String.downcase()
  end

  defp squish(name), do: name |> String.trim() |> String.replace(~r/\s+/u, " ")
end
