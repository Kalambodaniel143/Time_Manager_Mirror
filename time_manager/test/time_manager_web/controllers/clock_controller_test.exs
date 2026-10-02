defmodule TimeManagerWeb.ClockControllerTest do
  use TimeManagerWeb.ConnCase, async: true

  import TimeManager.AccountsFixtures

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
end
