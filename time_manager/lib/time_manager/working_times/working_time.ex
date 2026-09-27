defmodule TimeManager.WorkingTimes.WorkingTime do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workingtime" do
    field :start, :utc_datetime
    field :end, :utc_datetime

    belongs_to :user, TimeManager.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(working_time, attrs) do
    working_time
    |> cast(attrs, [:start, :end])
    |> validate_required([:start, :end, :user_id])
    |> validate_end_after_start()
    |> foreign_key_constraint(:user_id)
    |> check_constraint(:end, name: :end_after_start, message: "must be after start")
  end

  defp validate_end_after_start(changeset) do
    start = get_field(changeset, :start)
    finish = get_field(changeset, :end)

    if start && finish && DateTime.compare(finish, start) != :gt do
      add_error(changeset, :end, "must be after start")
    else
      changeset
    end
  end
end
