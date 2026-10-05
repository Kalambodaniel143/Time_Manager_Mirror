defmodule TimeManagerWeb.WorkingTimeControllerTest do
  use TimeManagerWeb.ConnCase, async: true

  import TimeManager.AccountsFixtures

  alias TimeManager.WorkingTimes

  @period %{start: "2026-09-22T08:00:00Z", end: "2026-09-22T17:00:00Z"}

  setup do
    admin = user_fixture(role: "administrator")
    manager = user_fixture(role: "manager")
    member = user_fixture()
    outsider = user_fixture()
    team_fixture(manager_id: manager.id, members: [member, manager])

    {:ok, period} = WorkingTimes.create_working_time(member.id, @period)
    {:ok, outsider_period} = WorkingTimes.create_working_time(outsider.id, @period)

    %{
      admin: admin,
      manager: manager,
      member: member,
      outsider: outsider,
      period: period,
      outsider_period: outsider_period
    }
  end

  describe "read" do
    test "self, own manager and administrator list the periods", %{conn: conn} = ctx do
      for viewer <- [ctx.member, ctx.manager, ctx.admin] do
        conn = conn |> log_in(viewer) |> get(~p"/api/workingtime/#{ctx.member.id}")
        assert [_] = json_response(conn, 200)["data"]
      end
    end

    test "an employee cannot list a colleague's periods (IDOR)", %{conn: conn} = ctx do
      conn = conn |> log_in(ctx.member) |> get(~p"/api/workingtime/#{ctx.outsider.id}")
      assert json_response(conn, 403)
    end

    test "own id in the URL does not open someone else's period", %{conn: conn} = ctx do
      conn =
        conn
        |> log_in(ctx.member)
        |> get(~p"/api/workingtime/#{ctx.member.id}/#{ctx.outsider_period.id}")

      assert json_response(conn, 404)
    end
  end

  describe "write" do
    test "an employee cannot create, correct or delete periods", %{conn: conn} = ctx do
      conn = log_in(conn, ctx.member)

      assert json_response(
               post(conn, ~p"/api/workingtime/#{ctx.member.id}", workingtime: @period),
               403
             )

      assert json_response(
               put(conn, ~p"/api/workingtime/#{ctx.period.id}", workingtime: @period),
               403
             )

      assert json_response(delete(conn, ~p"/api/workingtime/#{ctx.period.id}"), 403)
    end

    test "a manager corrects the hours of their team", %{conn: conn} = ctx do
      conn = log_in(conn, ctx.manager)

      assert json_response(
               post(conn, ~p"/api/workingtime/#{ctx.member.id}", workingtime: @period),
               201
             )

      updated =
        put(conn, ~p"/api/workingtime/#{ctx.period.id}",
          workingtime: %{end: "2026-09-22T16:00:00Z"}
        )

      assert json_response(updated, 200)["data"]["end"] == "2026-09-22 16:00:00"

      assert response(delete(conn, ~p"/api/workingtime/#{ctx.period.id}"), 204)
    end

    test "a manager never edits their own hours, even as a team member", %{conn: conn} = ctx do
      conn =
        conn
        |> log_in(ctx.manager)
        |> post(~p"/api/workingtime/#{ctx.manager.id}", workingtime: @period)

      assert json_response(conn, 403)
    end

    test "a manager cannot touch hours outside their teams", %{conn: conn} = ctx do
      conn = log_in(conn, ctx.manager)

      assert json_response(
               put(conn, ~p"/api/workingtime/#{ctx.outsider_period.id}", workingtime: @period),
               403
             )

      assert json_response(delete(conn, ~p"/api/workingtime/#{ctx.outsider_period.id}"), 403)
    end

    test "an administrator edits anyone's hours", %{conn: conn} = ctx do
      conn = log_in(conn, ctx.admin)

      assert json_response(
               put(conn, ~p"/api/workingtime/#{ctx.outsider_period.id}", workingtime: @period),
               200
             )
    end
  end
end
