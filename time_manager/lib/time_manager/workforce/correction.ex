defmodule TimeManager.Workforce.Correction do
  use Ecto.Schema

  schema "correction_requests" do
    field :user_id, :integer
    field :period_id, :integer
    field :before_start, :utc_datetime
    field :before_end, :utc_datetime
    field :start, :utc_datetime
    field :end, :utc_datetime
    field :reason, :string
    field :status, :string, default: "pending"
    field :reviewer_id, :integer
    field :review_reason, :string, default: ""
    field :reviewed_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
end
