defmodule TimeManager.Clocks.Clock do
  use Ecto.Schema
  import Ecto.Changeset

  schema "clocks" do
    field :time, :utc_datetime
    field :status, :boolean
    belongs_to :user, TimeManager.Accounts.User
    timestamps(type: :utc_datetime)
  end

  @doc """
  Validates a clock's time and status. Set user_id on the struct before calling.
  """
  def changeset(clock, attrs) do
    clock
    |> cast(attrs, [:time, :status])
    |> validate_required([:time, :status, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
