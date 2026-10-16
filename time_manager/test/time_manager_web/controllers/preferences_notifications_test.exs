defmodule TimeManagerWeb.PreferencesNotificationsTest do
  use TimeManagerWeb.ConnCase, async: true
  import TimeManager.AccountsFixtures
  alias TimeManager.Workforce

  test "language preferences persist for the current account and reject unsupported values" do
    user = user_fixture()
    conn = log_in(build_conn(), user)

    assert json_response(patch(conn, "/api/auth/preferences", language: "en"), 200)["data"][
             "language"
           ] == "en"

    assert json_response(get(conn, "/api/auth/preferences"), 200)["data"]["language"] == "en"
    assert json_response(patch(conn, "/api/auth/preferences", language: "xx"), 422)
    assert Workforce.preferences(user_fixture())["language"] == "fr"
  end

  test "unread count covers all pages and malformed pagination is rejected" do
    user = user_fixture()
    conn = log_in(build_conn(), user)
    for n <- 1..51, do: Workforce.notify(user.id, "Correction #{n}", "Modifiée")
    assert json_response(get(conn, "/api/notifications/count"), 200)["data"]["unread"] == 51

    assert length(
             json_response(get(conn, "/api/notifications?status=unread&page=1"), 200)["data"]
           ) == 50

    assert length(
             json_response(get(conn, "/api/notifications?status=unread&page=2"), 200)["data"]
           ) == 1

    assert json_response(get(conn, "/api/notifications?page[invalid]=1"), 422)
    assert json_response(get(conn, "/api/notifications?status=invalid"), 422)
  end
end
