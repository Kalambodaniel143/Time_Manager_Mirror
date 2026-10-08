defmodule TimeManager.Clocks do
  @moduledoc """
  Records clock events and creates a working period when an arrival is closed.
  """

  import Ecto.Query

  alias TimeManager.Accounts.User
  alias TimeManager.Clocks.Clock
  alias TimeManager.Repo
  alias TimeManager.WorkingTimes

  # Actions autorisées après chaque pointage.
  @next_kinds %{
    nil => [:arrival],
    :arrival => [:pause, :departure],
    :resume => [:pause, :departure],
    :pause => [:resume, :departure],
    :departure => [:arrival]
  }

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
  Records an arrival, pause, resume or departure.

  A pause or departure closes the current work segment. Resuming opens another
  segment, so breaks never enter workingtime totals. Leaving during a pause
  ends the service without creating another period. Events cannot precede the
  latest clock or be in the future relative to the server's UTC clock.
  A period must have a positive duration. Both records are committed together.

  The owner comes from the supplied user, never from attrs.
  Returns {:ok, clock}, {:error, changeset}, or {:error, :not_found}.
  """
  def create_clock(%User{} = user, attrs), do: record_clock(user, attrs, nil)

  @doc """
  Completes the currently open service at its actual departure time.
  The expected latest clock prevents a stale form from closing another service.
  Only departure times within the last seven days are accepted.
  """
  def complete_clock(%User{} = user, clock_id, time) do
    case Ecto.Type.cast(:id, clock_id) do
      {:ok, id} when id > 0 ->
        record_clock(user, %{time: time, status: false, kind: :departure}, id)

      _ ->
        {:error, :bad_request}
    end
  end

  defp record_clock(%User{id: user_id}, attrs, expected_clock_id) do
    changeset = Clock.changeset(%Clock{user_id: user_id}, attrs)

    with {:ok, clock} <- Ecto.Changeset.apply_action(changeset, :insert) do
      Repo.transact(fn ->
        # Lock the user even when no clocks exist yet. Concurrent clicks for the
        # same user must check the previous state one after the other.
        with %User{} <-
               Repo.one(from user in User, where: user.id == ^user_id, lock: "FOR UPDATE") ||
                 {:error, :not_found},
             previous = latest_clock(user_id),
             :ok <- validate_completion(previous, clock, changeset, expected_clock_id),
             :ok <- validate_transition(previous, clock, changeset),
             {:ok, saved_clock} <- Repo.insert(changeset),
             :ok <- create_period(previous, saved_clock) do
          {:ok, saved_clock}
        end
      end)
    end
  end

  defp validate_completion(_previous, _clock, _changeset, nil), do: :ok

  defp validate_completion(previous, clock, changeset, expected_clock_id) do
    now = DateTime.utc_now()

    cond do
      is_nil(previous) or previous.id != expected_clock_id or previous.kind == :departure ->
        invalid(changeset, :time, "Les pointages ont changé. Actualisez avant de réessayer.")

      DateTime.compare(clock.time, now) == :gt ->
        invalid(changeset, :time, "Le départ ne peut pas être dans le futur.")

      DateTime.compare(clock.time, DateTime.add(now, -7 * 86_400, :second)) == :lt ->
        invalid(
          changeset,
          :time,
          "Seuls les départs des 7 derniers jours peuvent être complétés."
        )

      DateTime.compare(clock.time, previous.time) == :lt or
          (previous.status and DateTime.compare(clock.time, previous.time) == :eq) ->
        invalid(changeset, :time, "Le départ doit suivre le dernier pointage enregistré.")

      true ->
        :ok
    end
  end

  defp latest_clock(user_id) do
    Clock
    |> where([clock], clock.user_id == ^user_id)
    |> order_by([clock], desc: clock.time, desc: clock.id)
    |> limit(1)
    |> Repo.one()
  end

  defp validate_transition(previous, clock, changeset) do
    previous_kind = previous && previous.kind

    cond do
      DateTime.compare(clock.time, DateTime.utc_now()) == :gt ->
        invalid(changeset, :time, "Le pointage ne peut pas être dans le futur.")

      clock.kind not in Map.fetch!(@next_kinds, previous_kind) ->
        invalid(changeset, :status, "action is not allowed after the latest clock event")

      previous && DateTime.compare(clock.time, previous.time) == :lt ->
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

  # Une arrivée ou une reprise ouvre une période ; une pause n'est pas du travail.
  defp create_period(_previous, %Clock{status: true}), do: :ok
  defp create_period(%Clock{kind: :pause}, %Clock{kind: :departure}), do: :ok

  defp create_period(%Clock{status: true} = arrival, %Clock{status: false} = departure) do
    with {:ok, _period} <-
           WorkingTimes.create_working_time(departure.user_id, %{
             start: arrival.time,
             end: departure.time
           }) do
      :ok
    end
  end
end
