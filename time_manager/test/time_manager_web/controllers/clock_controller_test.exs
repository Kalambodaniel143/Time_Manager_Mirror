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

    result =
      post(conn, path,
        clock: %{time: DateTime.to_iso8601(finish), status: true, kind: "arrival", user_id: -1}
      )

    assert %{"data" => clock} = json_response(result, 201)
    assert clock["status"] == false
    assert clock["kind"] == "departure"
    assert clock["user_id"] == user.id

    assert %{"data" => [_]} =
             json_response(get(recycle(result), "/api/workingtime/#{user.id}"), 200)

    duplicate = post(recycle(result), path, clock: %{time: DateTime.to_iso8601(finish)})
    assert %{"errors" => %{"time" => [_]}} = json_response(duplicate, 422)
  end

  test "complete endpoint rejects malformed parameters", %{conn: conn} do
    user = user_fixture()
    path = "/api/clocks/#{user.id}/1/complete"

    for body <- [%{}, %{clock: %{}}, %{clock: %{time: nil}}] do
      assert %{"errors" => _} = json_response(post(recycle(conn), path, body), 400)
    end

    body = %{clock: %{time: DateTime.to_iso8601(DateTime.utc_now())}}

    assert %{"errors" => _} =
             json_response(post(recycle(conn), "/api/clocks/abc/1/complete", body), 404)

    assert %{"errors" => _} =
             json_response(post(recycle(conn), "/api/clocks/#{user.id}/abc/complete", body), 400)
  end

  test "arrival and departure feed the workingtime API with one eight-hour period", %{conn: conn} do
    user = user_fixture()
    clock_path = "/api/clocks/#{user.id}"

    arrival = post(conn, clock_path, clock: %{time: "2026-09-28 09:00:00", status: true})
    assert %{"data" => %{"status" => true}} = json_response(arrival, 201)

    departure =
      post(recycle(arrival), clock_path, clock: %{time: "2026-09-28 17:00:00", status: false})

    assert %{"data" => %{"status" => false}} = json_response(departure, 201)

    periods = get(recycle(departure), "/api/workingtime/#{user.id}")
    assert %{"data" => [period]} = json_response(periods, 200)
    assert period["start"] == "2026-09-28 09:00:00"
    assert period["end"] == "2026-09-28 17:00:00"

    duplicate =
      post(recycle(periods), clock_path, clock: %{time: "2026-09-28 17:00:00", status: false})

    assert %{"errors" => %{"status" => [_]}} = json_response(duplicate, 422)
    periods = get(recycle(duplicate), "/api/workingtime/#{user.id}")
    assert %{"data" => [_]} = json_response(periods, 200)
  end

  test "departure without an arrival returns a validation error", %{conn: conn} do
    user = user_fixture()

    conn =
      post(conn, "/api/clocks/#{user.id}", clock: %{time: "2026-09-28 17:00:00", status: false})

    assert %{"errors" => %{"status" => [_]}} = json_response(conn, 422)
  end

  test "the API preserves pause/resume events and excludes the break from periods", %{conn: conn} do
    user = user_fixture()
    path = "/api/clocks/#{user.id}"

    for {time, status, kind} <- [
          {"2026-10-05 09:00:00", true, "arrival"},
          {"2026-10-05 10:00:00", false, "pause"},
          {"2026-10-05 10:30:00", true, "resume"},
          {"2026-10-05 12:00:00", false, "departure"}
        ] do
      result = post(recycle(conn), path, clock: %{time: time, status: status, kind: kind})
      assert %{"data" => %{"kind" => ^kind, "status" => ^status}} = json_response(result, 201)
    end

    assert %{"data" => events} = json_response(get(recycle(conn), path), 200)
    assert Enum.map(events, & &1["kind"]) == ["arrival", "pause", "resume", "departure"]
    periods = get(recycle(conn), "/api/workingtime/#{user.id}")
    assert %{"data" => [first, second]} = json_response(periods, 200)
    assert first["end"] == "2026-10-05 10:00:00"
    assert second["start"] == "2026-10-05 10:30:00"
  end
end
