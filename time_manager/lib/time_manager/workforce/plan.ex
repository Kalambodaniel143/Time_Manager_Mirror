defmodule TimeManager.Workforce.Plan do
  use Ecto.Schema

  schema "workforce_plans" do
    field :team_id, :integer
    field :start, :date
    field :days, :integer, default: 14
    field :revision, :integer, default: 1
    field :published_revision, :integer
    field :published_at, :utc_datetime
    field :snapshot, :map, default: %{}
    timestamps(type: :utc_datetime)
  end
end
