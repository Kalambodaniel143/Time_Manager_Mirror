defmodule TimeManager.ClocksCompletionTest do
  use TimeManager.DataCase, async: true

  import TimeManager.AccountsFixtures
  alias TimeManager.Clocks
  alias TimeManager.WorkingTimes

  setup do
    user = user_fixture()
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    start = DateTime.add(now, -2 * 86_400, :second)
    {:ok, arrival} = Clocks.create_clock(user, %{time: start, status: true})
    %{user: user, now: now, start: start, arrival: arrival}
  end

  test "completion uses the actual departure and cannot be repeated", c do
    finish = DateTime.add(c.start, 8 * 3600, :second)
    assert {:ok, clock} = Clocks.complete_clock(c.user, c.arrival.id, finish)
    assert clock.kind == :departure
    assert clock.status == false
    assert clock.time == finish
    assert {:ok, [period]} = WorkingTimes.list_working_times(c.user.id)
    assert period.start == c.start
    assert period.end == finish
    assert {:error, _} = Clocks.complete_clock(c.user, c.arrival.id, finish)
    assert {:ok, [_]} = WorkingTimes.list_working_times(c.user.id)
  end

  test "invalid, future, early and equal departure dates do not write anything", c do
    for finish <- [
          "invalid",
          DateTime.add(c.now, 60, :second),
          DateTime.add(c.start, -1, :second),
          c.start
        ] do
      assert {:error, %Ecto.Changeset{}} = Clocks.complete_clock(c.user, c.arrival.id, finish)
      assert [c.arrival] == Clocks.list_clocks(c.user)
      assert {:ok, []} = WorkingTimes.list_working_times(c.user.id)
    end
  end

  test "completion refuses a departure older than seven days", c do
    user = user_fixture()

    {:ok, arrival} =
      Clocks.create_clock(user, %{time: DateTime.add(c.now, -10 * 86_400, :second), status: true})

    assert {:error, changeset} =
             Clocks.complete_clock(user, arrival.id, DateTime.add(c.now, -8 * 86_400, :second))

    assert Enum.any?(errors_on(changeset).time, &String.contains?(&1, "7 derniers jours"))
    assert {:ok, []} = WorkingTimes.list_working_times(user.id)
  end

  test "an old form cannot close a newer service even with a later departure time", c do
    {:ok, _} =
      Clocks.create_clock(c.user, %{time: DateTime.add(c.start, 3600, :second), status: false})

    {:ok, newer} =
      Clocks.create_clock(c.user, %{time: DateTime.add(c.now, -3600, :second), status: true})

    assert {:error, changeset} =
             Clocks.complete_clock(c.user, c.arrival.id, DateTime.add(c.now, -60, :second))

    assert Enum.any?(errors_on(changeset).time, &String.contains?(&1, "Actualisez"))
    assert List.last(Clocks.list_clocks(c.user)).id == newer.id
    assert {:ok, [_]} = WorkingTimes.list_working_times(c.user.id)
  end

  test "completion during a pause creates no extra work", c do
    {:ok, pause} =
      Clocks.create_clock(c.user, %{
        time: DateTime.add(c.start, 3600, :second),
        status: false,
        kind: :pause
      })

    assert {:ok, _} =
             Clocks.complete_clock(c.user, pause.id, DateTime.add(c.start, 8 * 3600, :second))

    assert {:ok, [period]} = WorkingTimes.list_working_times(c.user.id)
    assert DateTime.diff(period.end, period.start) == 3600
  end

  test "completion after resuming excludes the pause from total hours", c do
    {:ok, _} =
      Clocks.create_clock(c.user, %{
        time: DateTime.add(c.start, 3600, :second),
        status: false,
        kind: :pause
      })

    {:ok, resume} =
      Clocks.create_clock(c.user, %{
        time: DateTime.add(c.start, 5400, :second),
        status: true,
        kind: :resume
      })

    assert {:ok, _} =
             Clocks.complete_clock(c.user, resume.id, DateTime.add(c.start, 3 * 3600, :second))

    {:ok, periods} = WorkingTimes.list_working_times(c.user.id)
    assert length(periods) == 2
    assert Enum.sum(Enum.map(periods, &DateTime.diff(&1.end, &1.start))) == 9000
  end

  test "completion validates the identifier and its owner", c do
    assert {:error, :bad_request} = Clocks.complete_clock(c.user, "abc", c.now)
    assert {:error, :bad_request} = Clocks.complete_clock(c.user, 0, c.now)
    other = user_fixture()
    assert {:error, %Ecto.Changeset{}} = Clocks.complete_clock(other, c.arrival.id, c.now)
    assert [] == Clocks.list_clocks(other)
    assert [c.arrival] == Clocks.list_clocks(c.user)
  end
end
