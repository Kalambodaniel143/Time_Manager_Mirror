defmodule TimeManagerWeb.TeamControllerTest do
  use TimeManagerWeb.ConnCase, async: true

  import TimeManager.AccountsFixtures

  setup do
    admin = user_fixture(role: "administrator")
    manager = user_fixture(role: "manager")
    member = user_fixture()
    team = team_fixture(name: "Voirie nuit", manager_id: manager.id, members: [member])
    %{admin: admin, manager: manager, member: member, team: team}
  end

  test "an administrator creates a team, names its manager and adds members",
       %{conn: conn} = ctx do
    conn = log_in(conn, ctx.admin)

    created =
      post(conn, ~p"/api/teams", team: %{name: "Espaces verts", manager_id: ctx.manager.id})

    assert %{"id" => id, "manager" => %{"id" => manager_id}} = json_response(created, 201)["data"]
    assert manager_id == ctx.manager.id

    added = post(conn, ~p"/api/teams/#{id}/members", user_id: ctx.member.id)
    assert [%{"id" => member_id}] = json_response(added, 200)["data"]["members"]
    assert member_id == ctx.member.id

    removed = delete(conn, ~p"/api/teams/#{id}/members/#{ctx.member.id}")
    assert json_response(removed, 200)["data"]["members"] == []
  end

  test "a team manager must have the manager role", %{conn: conn} = ctx do
    conn =
      conn
      |> log_in(ctx.admin)
      |> post(~p"/api/teams", team: %{name: "X", manager_id: ctx.member.id})

    assert %{"manager_id" => ["must have the manager role"]} = json_response(conn, 422)["errors"]
  end

  test "a manager cannot compose teams, even their own", %{conn: conn} = ctx do
    conn = log_in(conn, ctx.manager)
    outsider = user_fixture()

    assert json_response(
             post(conn, ~p"/api/teams/#{ctx.team.id}/members", user_id: outsider.id),
             403
           )

    assert json_response(post(conn, ~p"/api/teams", team: %{name: "Mine"}), 403)
    assert json_response(put(conn, ~p"/api/teams/#{ctx.team.id}", team: %{manager_id: nil}), 403)
  end

  test "a manager sees their team with its members", %{conn: conn} = ctx do
    conn = conn |> log_in(ctx.manager) |> get(~p"/api/teams")
    assert [%{"name" => "Voirie nuit", "members" => [_]}] = json_response(conn, 200)["data"]
  end

  test "an employee sees the names of their teams, not the other members", %{conn: conn} = ctx do
    conn = log_in(conn, ctx.member)

    assert [%{"name" => "Voirie nuit", "members" => []}] =
             json_response(get(conn, ~p"/api/teams"), 200)["data"]

    assert json_response(get(conn, ~p"/api/teams/#{ctx.team.id}"), 403)
  end
end
