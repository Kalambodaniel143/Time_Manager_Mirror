defmodule TimeManager.ClocksConcurrencyTest do
  # Independent database connections are required to exercise the user row lock.
  use ExUnit.Case, async: false

  import Ecto.Query
  alias Ecto.Adapters.SQL.Sandbox
  alias TimeManager.Accounts.User
  alias TimeManager.Clocks
  alias TimeManager.Clocks.Clock
  alias TimeManager.Repo
  alias TimeManager.WorkingTimes.WorkingTime

  setup do
    user =
      Sandbox.unboxed_run(Repo, fn ->
        Repo.insert!(%User{username: "clock_concurrency", email: "concurrency@example.test"})
      end)

    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        Repo.delete_all(from p in WorkingTime, where: p.user_id == ^user.id)
        Repo.delete_all(from c in Clock, where: c.user_id == ^user.id)
        Repo.delete!(user)
      end)
    end)

    %{user: user, supervisor: start_supervised!({Task.Supervisor, []})}
  end

  test "concurrent arrivals insert only one event", context do
    results = record_together(context, ~U[2026-09-28 09:00:00Z], true)
    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Ecto.Changeset{}}, &1)) == 1

    Sandbox.unboxed_run(Repo, fn ->
      assert length(Clocks.list_clocks(context.user)) == 1
    end)
  end

  test "concurrent departures create exactly one period", context do
    Sandbox.unboxed_run(Repo, fn ->
      assert {:ok, _} =
               Clocks.create_clock(context.user, %{time: ~U[2026-09-28 09:00:00Z], status: true})
    end)

    results = record_together(context, ~U[2026-09-28 17:00:00Z], false)
    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Ecto.Changeset{}}, &1)) == 1

    Sandbox.unboxed_run(Repo, fn ->
      assert length(Clocks.list_clocks(context.user)) == 2

      assert Repo.aggregate(from(p in WorkingTime, where: p.user_id == ^context.user.id), :count) ==
               1
    end)
  end

  defp record_together(context, time, status) do
    parent = self()

    tasks =
      for _ <- 1..2 do
        Task.Supervisor.async_nolink(context.supervisor, fn ->
          Sandbox.unboxed_run(Repo, fn ->
            send(parent, {:ready, self()})

            receive do
              :go -> Clocks.create_clock(context.user, %{time: time, status: status})
            after
              5_000 -> flunk("start signal not received")
            end
          end)
        end)
      end

    for _ <- tasks do
      assert_receive {:ready, _pid}, 5_000
    end

    Enum.each(tasks, &send(&1.pid, :go))
    Enum.map(tasks, &Task.await(&1, 5_000))
  end
end
