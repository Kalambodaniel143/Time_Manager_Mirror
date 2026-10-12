defmodule TimeManager.Workforce.Setting do
  use Ecto.Schema

  schema "workforce_settings" do
    field :organization_id, :binary_id
    field :rules, :map
    timestamps(type: :utc_datetime)
  end
end
