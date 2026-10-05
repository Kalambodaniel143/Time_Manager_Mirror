defmodule TimeManagerWeb.ClockControllerTest do
  use TimeManagerWeb.ConnCase, async: true

  import TimeManager.AccountsFixtures

  test "complete endpoint creates a departure and its period, ignoring extra fields", %{
    conn: conn
  } do
    user = user_fixture()
    start = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-2 * 86_400, :second)
    {:ok, arrival} = TimeManager.Clocks.create_clock(user, %{time: start, status: true})
    finish = DateTime.add(start, 8 * 3600, :second)
    path = "/api/clocks/#{user.id}/#{arrival.id}/complete"
    conn = log_in(conn, user)

    result =
      post(conn, path,
        clock: %{time: DateTime.to_iso8601(finish), status: true, kind: "arrival", user_id: -1}
      )

    assert %{"data" => clock} = json_response(result, 201)
    assert clock["status"] == false
    assert clock["kind"] == "departure"
    assert clock["user_id"] == user.id

    assert %{"data" => [_]} =
             json_response(get(conn, "/api/workingtime/#{user.id}"), 200)

    duplicate = post(conn, path, clock: %{time: DateTime.to_iso8601(finish)})
    assert %{"errors" => %{"time" => [_]}} = json_response(duplicate, 422)
  end

  test "complete endpoint rejects malformed parameters", %{conn: conn} do
    user = user_fixture()
    conn = log_in(conn, user)
    path = "/api/clocks/#{user.id}/1/complete"

    for body <- [%{}, %{clock: %{}}, %{clock: %{time: nil}}] do
      assert %{"errors" => _} = json_response(post(conn, path, body), 400)
    end

    body = %{clock: %{time: DateTime.to_iso8601(DateTime.utc_now())}}

    assert %{"errors" => _} =
             json_response(post(conn, "/api/clocks/abc/1/complete", body), 404)

    assert %{"errors" => _} =
             json_response(post(conn, "/api/clocks/#{user.id}/abc/complete", body), 400)
  end

  test "nobody completes someone else's departure, not even the manager", %{conn: conn} do
    member = user_fixture()
    manager = user_fixture(role: "manager")
    team_fixture(manager_id: manager.id, members: [member])
    start = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-2 * 86_400, :second)
    {:ok, arrival} = TimeManager.Clocks.create_clock(member, %{time: start, status: true})
    path = "/api/clocks/#{member.id}/#{arrival.id}/complete"
    body = %{clock: %{time: DateTime.to_iso8601(DateTime.add(start, 8 * 3600, :second))}}

    assert json_response(post(conn, path, body), 401)

    for author <- [user_fixture(), manager, user_fixture(role: "administrator")] do
      assert json_response(conn |> log_in(author) |> post(path, body), 403)
    end

    assert [_] = TimeManager.Clocks.list_clocks(member)
  end

  test "arrival and departure feed the workingtime API with one eight-hour period", %{conn: conn} do
    user = user_fixture()
    conn = log_in(conn, user)
    clock_path = "/api/clocks/#{user.id}"

    arrival = post(conn, clock_path, clock: %{time: "2026-09-28 09:00:00", status: true})
    assert %{"data" => %{"status" => true}} = json_response(arrival, 201)

    departure = post(conn, clock_path, clock: %{time: "2026-09-28 17:00:00", status: false})
    assert %{"data" => %{"status" => false}} = json_response(departure, 201)

    periods = get(conn, "/api/workingtime/#{user.id}")
    assert %{"data" => [period]} = json_response(periods, 200)
    assert period["start"] == "2026-09-28 09:00:00"
    assert period["end"] == "2026-09-28 17:00:00"

    duplicate = post(conn, clock_path, clock: %{time: "2026-09-28 17:00:00", status: false})
    assert %{"errors" => %{"status" => [_]}} = json_response(duplicate, 422)
    assert %{"data" => [_]} = json_response(get(conn, "/api/workingtime/#{user.id}"), 200)
  end

  test "departure without an arrival returns a validation error", %{conn: conn} do
    user = user_fixture()

    conn =
      conn
      |> log_in(user)
      |> post("/api/clocks/#{user.id}", clock: %{time: "2026-09-28 17:00:00", status: false})

    assert %{"errors" => %{"status" => [_]}} = json_response(conn, 422)
  end

  test "the API preserves pause/resume events and excludes the break from periods", %{conn: conn} do
    user = user_fixture()
    conn = log_in(conn, user)
    path = "/api/clocks/#{user.id}"

    for {time, status, kind} <- [
          {"2026-10-05 09:00:00", true, "arrival"},
          {"2026-10-05 10:00:00", false, "pause"},
          {"2026-10-05 10:30:00", true, "resume"},
          {"2026-10-05 12:00:00", false, "departure"}
        ] do
      result = post(conn, path, clock: %{time: time, status: status, kind: kind})
      assert %{"data" => %{"kind" => ^kind, "status" => ^status}} = json_response(result, 201)
    end

    assert %{"data" => events} = json_response(get(conn, path), 200)
    assert Enum.map(events, & &1["kind"]) == ["arrival", "pause", "resume", "departure"]
    periods = get(conn, "/api/workingtime/#{user.id}")
    assert %{"data" => [first, second]} = json_response(periods, 200)
    assert first["end"] == "2026-10-05 10:00:00"
    assert second["start"] == "2026-10-05 10:30:00"
  end

  test "nobody clocks for someone else, not even an administrator or the manager", %{conn: conn} do
    member = user_fixture()
    manager = user_fixture(role: "manager")
    admin = user_fixture(role: "administrator")
    team_fixture(manager_id: manager.id, members: [member])

    for author <- [user_fixture(), manager, admin] do
      conn =
        conn
        |> log_in(author)
        |> post("/api/clocks/#{member.id}", clock: %{time: "2026-09-28 09:00:00", status: true})

      assert json_response(conn, 403)
    end
  end

  test "clock history: self, own manager and administrator only", %{conn: conn} do
    member = user_fixture()
    manager = user_fixture(role: "manager")
    team_fixture(manager_id: manager.id, members: [member])

    assert json_response(conn |> log_in(manager) |> get("/api/clocks/#{member.id}"), 200)
    assert json_response(conn |> log_in(user_fixture()) |> get("/api/clocks/#{member.id}"), 403)

    assert json_response(
             conn |> log_in(user_fixture(role: "manager")) |> get("/api/clocks/#{member.id}"),
             403
           )
  end

  test "requires a session", %{conn: conn} do
    user = user_fixture()
    assert json_response(get(conn, "/api/clocks/#{user.id}"), 401)
  end
end
