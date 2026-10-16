defmodule TimeManager.Workforce.PayProfile do
  use Ecto.Schema

  schema "payroll_profiles" do
    field :user_id, :integer
    field :hourly_rate, :decimal
    field :currency, :string, default: "EUR"
    timestamps(type: :utc_datetime)
  end
end
