defmodule TimeManager.Workforce.Notification do
  use Ecto.Schema

  schema "workforce_notifications" do
    field :user_id, :integer
    field :title, :string
    field :body, :string
    field :read_at, :utc_datetime
    timestamps(type: :utc_datetime, updated_at: false)
  end
end
