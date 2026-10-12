defmodule TimeManager.Workforce.Permission do
  use Ecto.Schema

  schema "team_permissions" do
    field :team_id, :integer
    field :validate, :boolean, default: true
    field :correct, :boolean, default: true
    field :publish, :boolean, default: false
    timestamps(type: :utc_datetime)
  end
end
