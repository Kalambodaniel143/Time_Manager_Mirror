defmodule TimeManager.Workforce.Event do
  use Ecto.Schema

  schema "workforce_events" do
    field :organization_id, :binary_id
    field :actor_id, :integer
    field :action, :string
    field :details, :map, default: %{}
    timestamps(type: :utc_datetime, updated_at: false)
  end
end
