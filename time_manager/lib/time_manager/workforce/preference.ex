defmodule TimeManager.Workforce.Preference do
  use Ecto.Schema

  schema "account_preferences" do
    field :user_id, :integer
    field :settings, :map
    timestamps(type: :utc_datetime)
  end
end
