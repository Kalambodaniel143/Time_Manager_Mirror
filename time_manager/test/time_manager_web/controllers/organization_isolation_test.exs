defmodule TimeManagerWeb.OrganizationIsolationTest do
  @moduledoc """
  No role reaches the data of another organization through the existing routes
  (users, teams, clocks, working times), whatever the ids put in the URL.
  """
  use TimeManagerWeb.ConnCase, async: true

  import TimeManager.AccountsFixtures

  setup do
    admin = organization_admin_fixture()
    colleague = user_fixture(organization_id: admin.organization_id)
    other_admin = organization_admin_fixture()
    stranger = user_fixture(organization_id: other_admin.organization_id)
    legacy_admin = user_fixture(role: "administrator")

    %{
      admin: admin,
      colleague: colleague,
      other_admin: other_admin,
      stranger: stranger,
      legacy_admin: legacy_admin
    }
  end

  test "an administrator lists the users of their organization only", %{conn: conn} = ctx do
    ids = conn |> log_in(ctx.admin) |> get(~p"/api/users") |> json_response(200) |> ids()
    assert Enum.sort(ids) == Enum.sort([ctx.admin.id, ctx.colleague.id])

    legacy =
      conn |> log_in(ctx.legacy_admin) |> get(~p"/api/users") |> json_response(200) |> ids()

    refute ctx.admin.id in legacy
    refute ctx.stranger.id in legacy
  end

  test "an administrator cannot read, edit, demote or delete a stranger", %{conn: conn} = ctx do
    conn = log_in(conn, ctx.admin)

    assert json_response(get(conn, ~p"/api/users/#{ctx.stranger}"), 403)
    assert json_response(put(conn, ~p"/api/users/#{ctx.stranger}", user: %{username: "x"}), 403)
    assert json_response(put(conn, ~p"/api/users/#{ctx.stranger}/role", role: "manager"), 403)
    assert json_response(delete(conn, ~p"/api/users/#{ctx.stranger}"), 403)
    assert json_response(get(conn, ~p"/api/clocks/#{ctx.stranger.id}"), 403)
    assert json_response(get(conn, ~p"/api/workingtime/#{ctx.stranger.id}"), 403)

    assert json_response(
             post(conn, ~p"/api/workingtime/#{ctx.stranger.id}",
               working_time: %{start: "2026-10-06 08:00:00", end: "2026-10-06 12:00:00"}
             ),
             403
           )
  end

  test "a user created by an administrator joins their organization", %{conn: conn} = ctx do
    attrs = %{
      username: "new",
      email: unique_email(),
      password: valid_password(),
      role: "employee"
    }

    conn = conn |> log_in(ctx.admin) |> post(~p"/api/users", user: attrs)
    assert json_response(conn, 201)["data"]["organization_id"] == ctx.admin.organization_id
  end

  test "personal details are hidden from managers", %{conn: conn} = ctx do
    manager = user_fixture(role: "manager", organization_id: ctx.admin.organization_id)

    team_fixture(
      manager_id: manager.id,
      members: [ctx.colleague],
      organization_id: ctx.admin.organization_id
    )

    seen = conn |> log_in(manager) |> get(~p"/api/users/#{ctx.colleague}") |> json_response(200)
    refute Map.has_key?(seen["data"], "birth_date")

    seen = conn |> log_in(ctx.admin) |> get(~p"/api/users/#{ctx.colleague}") |> json_response(200)
    assert Map.has_key?(seen["data"], "birth_date")
  end

  describe "teams" do
    setup ctx do
      manager = user_fixture(role: "manager", organization_id: ctx.admin.organization_id)

      team =
        team_fixture(
          name: "Voirie",
          manager_id: manager.id,
          organization_id: ctx.admin.organization_id
        )

      %{manager: manager, team: team}
    end

    test "each organization sees and names its own teams", %{conn: conn} = ctx do
      other = log_in(conn, ctx.other_admin)

      assert json_response(get(other, ~p"/api/teams"), 200)["data"] == []
      assert json_response(get(other, ~p"/api/teams/#{ctx.team.id}"), 403)
      assert json_response(delete(other, ~p"/api/teams/#{ctx.team.id}"), 404)

      # The same name is free in another organization.
      assert json_response(post(other, ~p"/api/teams", team: %{name: "Voirie"}), 201)
    end

    test "a stranger can be neither manager nor member of a team", %{conn: conn} = ctx do
      conn = log_in(conn, ctx.admin)

      other_manager =
        user_fixture(role: "manager", organization_id: ctx.other_admin.organization_id)

      assert %{"manager_id" => _} =
               json_response(
                 post(conn, ~p"/api/teams", team: %{name: "X", manager_id: other_manager.id}),
                 422
               )["errors"]

      added = post(conn, ~p"/api/teams/#{ctx.team.id}/members", user_id: ctx.stranger.id)
      assert json_response(added, 404)
    end
  end

  defp ids(%{"data" => users}), do: Enum.map(users, & &1["id"])
end
