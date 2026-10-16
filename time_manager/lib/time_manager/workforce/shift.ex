defmodule TimeManager.Workforce.Shift do
  use Ecto.Schema

  schema "planned_shifts" do
    field :plan_id, :integer
    field :user_id, :integer
    field :start, :utc_datetime
    field :end, :utc_datetime
    field :kind, :string, default: "day"
    field :place, :string, default: ""
    timestamps(type: :utc_datetime)
  end
end
