defmodule TimeManager.Clocks.Clock do
  use Ecto.Schema
  import Ecto.Changeset

  schema "clocks" do
    field :time, :utc_datetime
    field :status, :boolean
    field :kind, Ecto.Enum, values: [:arrival, :departure, :pause, :resume]
    belongs_to :user, TimeManager.Accounts.User
    timestamps(type: :utc_datetime)
  end

  @doc """
  Validates a clock event. Set user_id on the struct before calling.
  Requests without kind retain the original arrival/departure behavior.
  """
  def changeset(clock, attrs) do
    clock
    |> cast(attrs, [:time, :status, :kind])
    |> default_kind()
    |> validate_required([:time, :status, :kind, :user_id])
    |> validate_kind_status()
    |> foreign_key_constraint(:user_id)
    |> check_constraint(:kind, name: :clocks_kind_matches_status)
  end

  defp default_kind(changeset) do
    case {get_field(changeset, :kind), get_field(changeset, :status)} do
      {nil, true} -> put_change(changeset, :kind, :arrival)
      {nil, false} -> put_change(changeset, :kind, :departure)
      _ -> changeset
    end
  end

  defp validate_kind_status(changeset) do
    kind = get_field(changeset, :kind)
    status = get_field(changeset, :status)

    if kind && not is_nil(status) && status != kind in [:arrival, :resume] do
      add_error(changeset, :status, "must match the clock kind")
    else
      changeset
    end
  end
end
