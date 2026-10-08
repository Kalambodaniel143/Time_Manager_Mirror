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

  test "future events are rejected for every valid transition without changing work", %{
    user: user
  } do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    future = DateTime.add(now, 3600)

    for {previous, allowed} <- [
          {nil, [:arrival]},
          {:arrival, [:pause, :departure]},
          {:pause, [:resume, :departure]},
          {:resume, [:pause, :departure]},
          {:departure, [:arrival]}
        ] do
      if previous do
        time = DateTime.add(now, -600 + length(Clocks.list_clocks(user)) * 60)

        assert {:ok, _} =
                 Clocks.create_clock(user, %{
                   time: time,
                   kind: previous,
                   status: previous in [:arrival, :resume]
                 })
      end

      clocks = Clocks.list_clocks(user)
      periods = WorkingTimes.list_working_times(user.id)

      for kind <- allowed do
        assert {:error, changeset} =
                 Clocks.create_clock(user, %{
                   time: future,
                   kind: kind,
                   status: kind in [:arrival, :resume]
                 })

        assert errors_on(changeset).time == ["Le pointage ne peut pas être dans le futur."]
        assert Clocks.list_clocks(user) == clocks
        assert WorkingTimes.list_working_times(user.id) == periods
      end
    end
  end

  test "the current UTC second is accepted", %{user: user} do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    assert {:ok, %{time: ^now}} = Clocks.create_clock(user, %{time: now, status: true})
  end

  test "a deleted user cannot record clocks or periods", %{user: user} do
    Repo.delete!(user)
    assert {:error, :not_found} = Clocks.create_clock(user, %{time: @arrival, status: true})
    assert Repo.aggregate(Clock, :count) == 0
    assert Repo.aggregate(WorkingTime, :count) == 0
  end

  test "equal timestamps preserve event order and the next transition", %{user: user} do
    pause_time = DateTime.add(@arrival, 3600)

    for {time, status, kind} <- [
          {@arrival, true, :arrival},
          {pause_time, false, :pause},
          {pause_time, true, :resume},
          {@departure, false, :departure}
        ] do
      assert {:ok, _} = Clocks.create_clock(user, %{time: time, status: status, kind: kind})
    end

    assert Enum.map(Clocks.list_clocks(user), & &1.kind) == [
             :arrival,
             :pause,
             :resume,
             :departure
           ]

    assert {:ok, [first, second]} = WorkingTimes.list_working_times(user.id)
    assert first.end == second.start
  end

  test "a half-hour pause leaves two and a half hours of work between 9 and 12", %{user: user} do
    for {time, status, kind} <- [
          {~U[2026-09-28 09:00:00Z], true, "arrival"},
          {~U[2026-09-28 10:00:00Z], false, "pause"},
          {~U[2026-09-28 10:30:00Z], true, "resume"},
          {~U[2026-09-28 12:00:00Z], false, "departure"}
        ] do
      assert {:ok, _} = Clocks.create_clock(user, %{time: time, status: status, kind: kind})
    end

    assert {:ok, [first, second]} = WorkingTimes.list_working_times(user.id)
    assert first.end == ~U[2026-09-28 10:00:00Z]
    assert second.start == ~U[2026-09-28 10:30:00Z]
    assert DateTime.diff(first.end, first.start) + DateTime.diff(second.end, second.start) == 9000

    assert Enum.map(Clocks.list_clocks(user), & &1.kind) == [
             :arrival,
             :pause,
             :resume,
             :departure
           ]
  end

  test "leaving during a pause adds no period and closes the service", %{user: user} do
    assert {:ok, arrival} = Clocks.create_clock(user, %{time: @arrival, status: true})
    assert arrival.kind == :arrival

    assert {:ok, _} =
             Clocks.create_clock(user, %{
               time: DateTime.add(@arrival, 3600),
               status: false,
               kind: :pause
             })

    assert {:ok, departure} = Clocks.create_clock(user, %{time: @departure, status: false})
    assert departure.kind == :departure
    assert {:ok, [period]} = WorkingTimes.list_working_times(user.id)
    assert DateTime.diff(period.end, period.start) == 3600

    assert {:error, _} =
             Clocks.create_clock(user, %{time: @departure, status: true, kind: :resume})

    assert {:ok, _} = Clocks.create_clock(user, %{time: @departure, status: true})
  end

  test "pause and resume must follow the service state", %{user: user} do
    assert {:error, _} = Clocks.create_clock(user, %{time: @arrival, status: false, kind: :pause})
    assert {:error, _} = Clocks.create_clock(user, %{time: @arrival, status: true, kind: :resume})
    assert {:ok, _} = Clocks.create_clock(user, %{time: @arrival, status: true})

    assert {:error, _} =
             Clocks.create_clock(user, %{time: @departure, status: true, kind: :resume})

    pause_time = DateTime.add(@arrival, 3600)
    assert {:ok, _} = Clocks.create_clock(user, %{time: pause_time, status: false, kind: :pause})

    assert {:error, _} =
             Clocks.create_clock(user, %{time: pause_time, status: false, kind: :pause})

    assert {:error, _} =
             Clocks.create_clock(user, %{time: pause_time, status: true, kind: :arrival})

    assert {:error, changeset} =
             Clocks.create_clock(user, %{time: @arrival, status: true, kind: :resume})

    assert errors_on(changeset).time != []
    assert {:ok, _} = Clocks.create_clock(user, %{time: pause_time, status: true, kind: :resume})

    assert {:error, _} =
             Clocks.create_clock(user, %{time: pause_time, status: true, kind: :resume})

    assert length(Clocks.list_clocks(user)) == 3
  end

  test "an invalid pause rolls back without closing the work segment", %{user: user} do
    assert {:ok, _} = Clocks.create_clock(user, %{time: @arrival, status: true})
    assert {:error, _} = Clocks.create_clock(user, %{time: @arrival, status: false, kind: :pause})
    assert [%Clock{kind: :arrival}] = Clocks.list_clocks(user)
    assert {:ok, []} = WorkingTimes.list_working_times(user.id)
  end

  test "unknown kinds and inconsistent statuses are rejected", %{user: user} do
    for attrs <- [
          %{time: @arrival, status: true, kind: "unknown"},
          %{time: @arrival, status: false, kind: "arrival"},
          %{time: @arrival, status: true, kind: "pause"}
        ] do
      assert {:error, _} = Clocks.create_clock(user, attrs)
    end

    assert Clocks.list_clocks(user) == []
  end
end
