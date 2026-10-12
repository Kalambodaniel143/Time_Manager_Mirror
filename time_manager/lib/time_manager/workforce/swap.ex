defmodule TimeManager.Workforce.Swap do
  use Ecto.Schema

  schema "shift_swaps" do
    field :user_id, :integer
    field :target_user_id, :integer
    field :shift_id, :integer
    field :target_shift_id, :integer
    field :proposal, :map
    field :reason, :string
    field :status, :string, default: "pending"
    field :reviewer_id, :integer
    field :review_reason, :string, default: ""
    field :reviewed_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
end
