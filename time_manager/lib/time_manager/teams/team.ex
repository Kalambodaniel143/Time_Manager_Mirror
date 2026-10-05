defmodule TimeManager.Teams.Team do
  use Ecto.Schema
  import Ecto.Changeset

  schema "teams" do
    field :name, :string

    belongs_to :manager, TimeManager.Accounts.User
    many_to_many :members, TimeManager.Accounts.User, join_through: "team_members"

    timestamps(type: :utc_datetime)
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :manager_id])
    |> validate_required([:name])
    |> validate_length(:name, max: 120)
    |> unique_constraint(:name)
    |> foreign_key_constraint(:manager_id)
  end
end
