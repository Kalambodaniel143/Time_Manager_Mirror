defmodule TimeManager.Workforce.Absence do
  use Ecto.Schema

  schema "absence_requests" do
    field :user_id, :integer
    field :start, :utc_datetime
    field :end, :utc_datetime
    field :payable_hours, :decimal
    field :kind, :string
    field :reason, :string, default: ""
    field :status, :string, default: "pending"
    field :reviewer_id, :integer
    field :review_reason, :string, default: ""
    field :reviewed_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
end
