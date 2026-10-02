defmodule TimeManager.ClocksTest do
  use TimeManager.DataCase, async: true

  alias TimeManager.Clocks
  alias TimeManager.Clocks.Clock
  alias TimeManager.WorkingTimes
  alias TimeManager.WorkingTimes.WorkingTime

  import TimeManager.AccountsFixtures

  @arrival ~U[2026-09-28 09:00:00Z]
  @departure ~U[2026-09-28 17:00:00Z]

  setup do
    %{user: user_fixture()}
  end

  test "arrival alone creates no completed period", %{user: user} do
    assert {:ok, clock} = Clocks.create_clock(user, %{time: @arrival, status: true})
    assert clock.status
    assert {:ok, []} = WorkingTimes.list_working_times(user.id)
  end

  test "departure creates exactly one period for this user", %{user: user} do
    other_user = user_fixture()
    assert {:ok, _} = Clocks.create_clock(user, %{time: @arrival, status: true})

    assert {:ok, departure} =
             Clocks.create_clock(user, %{time: @departure, status: false, user_id: other_user.id})

    refute departure.status
    assert {:ok, [period]} = WorkingTimes.list_working_times(user.id)
    assert period.start == @arrival
    assert period.end == @departure
    assert DateTime.diff(period.end, period.start, :second) == 8 * 3600
    assert {:ok, []} = WorkingTimes.list_working_times(other_user.id)
  end

  test "accepts the subject date format and preserves status false", %{user: user} do
    assert {:ok, _} =
             Clocks.create_clock(user, %{"time" => "2026-09-28 09:00:00", "status" => true})

    assert {:ok, clock} =
             Clocks.create_clock(user, %{"time" => "2026-09-28 17:00:00", "status" => false})

    refute clock.status
    assert Repo.aggregate(WorkingTime, :count) == 1
  end

  test "departure without arrival is rejected without inserting anything", %{user: user} do
    assert {:error, changeset} = Clocks.create_clock(user, %{time: @departure, status: false})
    assert errors_on(changeset).status != []
    assert Repo.aggregate(Clock, :count) == 0
    assert Repo.aggregate(WorkingTime, :count) == 0
  end

  test "repeated arrivals and departures do not duplicate periods", %{user: user} do
    assert {:ok, _} = Clocks.create_clock(user, %{time: @arrival, status: true})
    assert {:error, _} = Clocks.create_clock(user, %{time: @arrival, status: true})
    assert {:ok, _} = Clocks.create_clock(user, %{time: @departure, status: false})
    assert {:error, _} = Clocks.create_clock(user, %{time: @departure, status: false})
    assert Repo.aggregate(Clock, :count) == 2
    assert Repo.aggregate(WorkingTime, :count) == 1
  end

  test "a zero duration rolls back the departure when the period fails validation", %{user: user} do
    assert {:ok, _} = Clocks.create_clock(user, %{time: @arrival, status: true})
    assert {:error, changeset} = Clocks.create_clock(user, %{time: @arrival, status: false})
    assert errors_on(changeset).end != []
    assert [%Clock{status: true}] = Clocks.list_clocks(user)
    assert Repo.aggregate(WorkingTime, :count) == 0

    # The failed departure did not close the arrival; the next valid retry works.
    assert {:ok, _} = Clocks.create_clock(user, %{time: @departure, status: false})
    assert Repo.aggregate(WorkingTime, :count) == 1
  end

  test "backdated clocks are rejected", %{user: user} do
    assert {:ok, _} = Clocks.create_clock(user, %{time: @arrival, status: true})

    assert {:error, changeset} =
             Clocks.create_clock(user, %{time: DateTime.add(@arrival, -1), status: false})

    assert errors_on(changeset).time != []
    assert length(Clocks.list_clocks(user)) == 1
  end

  test "each pair creates its own period, including overnight work", %{user: user} do
    for {time, status} <- [
          {@arrival, true},
          {@departure, false},
          {~U[2026-09-28 22:00:00Z], true},
          {~U[2026-09-29 06:00:00Z], false}
        ] do
      assert {:ok, _} = Clocks.create_clock(user, %{time: time, status: status})
    end

    assert {:ok, periods} = WorkingTimes.list_working_times(user.id)
    assert length(periods) == 2
    assert Enum.sum(Enum.map(periods, &DateTime.diff(&1.end, &1.start))) == 16 * 3600
  end

  test "invalid fields return a changeset without writing", %{user: user} do
    assert {:error, changeset} = Clocks.create_clock(user, %{time: "bad", status: true})
    assert errors_on(changeset).time != []
    assert Clocks.list_clocks(user) == []
  end
end
