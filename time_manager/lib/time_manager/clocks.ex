defmodule TimeManager.Clocks do
  @moduledoc """
  Records clock events and creates a working period when an arrival is closed.
  """

  import Ecto.Query

  alias TimeManager.Accounts.User
  alias TimeManager.Clocks.Clock
  alias TimeManager.Repo
  alias TimeManager.WorkingTimes

  @doc """
  Lists a persisted user's clockings, oldest first.
  """
  def list_clocks(%User{id: user_id}) do
    Clock
    |> where([clock], clock.user_id == ^user_id)
    |> order_by([clock], asc: clock.time, asc: clock.id)
    |> Repo.all()
  end

  @doc """
  Records an arrival (true), or a departure (false) with its working period.

  A departure closes the last arrival. Events must alternate and cannot be
  backdated before the latest event. A period must have a positive duration.
  Both records are committed together, or neither is saved.

  The owner comes from the supplied user, never from attrs.
  Returns {:ok, clock}, {:error, changeset}, or {:error, :not_found}.
  """
  def create_clock(%User{id: user_id}, attrs) do
    changeset = Clock.changeset(%Clock{user_id: user_id}, attrs)

    with {:ok, clock} <- Ecto.Changeset.apply_action(changeset, :insert) do
      Repo.transact(fn ->
        # Lock the user even when no clocks exist yet. Concurrent clicks for the
        # same user must check the previous state one after the other.
        case Repo.one(from user in User, where: user.id == ^user_id, lock: "FOR UPDATE") do
          nil ->
            {:error, :not_found}

          _user ->
            previous = latest_clock(user_id)

            with :ok <- validate_transition(previous, clock, changeset),
                 {:ok, saved_clock} <- Repo.insert(changeset),
                 :ok <- create_period(previous, saved_clock) do
              {:ok, saved_clock}
            end
        end
      end)
    end
  end

  defp latest_clock(user_id) do
    Clock
    |> where([clock], clock.user_id == ^user_id)
    |> order_by([clock], desc: clock.time, desc: clock.id)
    |> limit(1)
    |> Repo.one()
  end

  defp validate_transition(nil, %Clock{status: false}, changeset) do
    invalid(changeset, :status, "must record an arrival before a departure")
  end

  defp validate_transition(nil, %Clock{status: true}, _changeset), do: :ok

  defp validate_transition(previous, clock, changeset) do
    cond do
      previous.status == clock.status ->
        invalid(changeset, :status, "must alternate arrivals and departures")

      DateTime.compare(clock.time, previous.time) == :lt ->
        invalid(changeset, :time, "must not precede the latest clock event")

      true ->
        :ok
    end
  end

  defp invalid(changeset, field, message) do
    changeset
    |> Ecto.Changeset.add_error(field, message)
    |> Ecto.Changeset.apply_action(:insert)
  end

  # Arrivals do not create a period: its end is not known yet.
  defp create_period(_previous, %Clock{status: true}), do: :ok

  defp create_period(%Clock{status: true} = arrival, %Clock{status: false} = departure) do
    case WorkingTimes.create_working_time(departure.user_id, %{
           start: arrival.time,
           end: departure.time
         }) do
      {:ok, _period} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
