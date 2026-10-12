defmodule TimeManager.Workforce.Sheet do
  use Ecto.Schema

  schema "weekly_sheets" do
    field :user_id, :integer
    field :week, :date
    field :note, :string, default: ""
    field :status, :string, default: "open"
    field :reviewer_id, :integer
    field :reviewed_at, :utc_datetime
    field :reason, :string, default: ""
    timestamps(type: :utc_datetime)
  end
end
