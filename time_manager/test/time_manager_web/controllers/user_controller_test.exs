defmodule TimeManagerWeb.UserControllerTest do
  use TimeManagerWeb.ConnCase

  import TimeManager.AccountsFixtures

  setup do
    admin = user_fixture(role: "administrator", username: "admin")
    manager = user_fixture(role: "manager", username: "manager")
    member = user_fixture(username: "member")
    outsider = user_fixture(username: "outsider")
    team_fixture(manager_id: manager.id, members: [member])

    %{admin: admin, manager: manager, member: member, outsider: outsider}
  end

  describe "index" do
    test "an administrator sees everyone", %{conn: conn, admin: admin} do
      conn = conn |> log_in(admin) |> get(~p"/api/users")
      assert length(json_response(conn, 200)["data"]) == 4
    end

    test "a manager sees themselves and their team only", %{conn: conn} = ctx do
      conn = conn |> log_in(ctx.manager) |> get(~p"/api/users")
      ids = Enum.map(json_response(conn, 200)["data"], & &1["id"])
      assert Enum.sort(ids) == Enum.sort([ctx.manager.id, ctx.member.id])
    end

    test "an employee cannot search users", %{conn: conn, member: member} do
      conn = conn |> log_in(member) |> get(~p"/api/users")
      assert json_response(conn, 403)
    end

    test "filters still apply inside the scope", %{conn: conn, admin: admin, member: member} do
      conn = conn |> log_in(admin) |> get(~p"/api/users?email=#{member.email}")
      assert [%{"id" => id}] = json_response(conn, 200)["data"]
      assert id == member.id
    end
  end

  describe "show" do
    test "self, own manager and administrator can read a profile", %{conn: conn} = ctx do
      for viewer <- [ctx.member, ctx.manager, ctx.admin] do
        conn = conn |> log_in(viewer) |> get(~p"/api/users/#{ctx.member}")
        assert json_response(conn, 200)["data"]["id"] == ctx.member.id
      end
    end

    test "changing the id in the URL does not reveal a colleague (IDOR)", %{conn: conn} = ctx do
      conn = conn |> log_in(ctx.member) |> get(~p"/api/users/#{ctx.outsider}")
      assert json_response(conn, 403)
    end

    test "a manager cannot read someone outside their teams", %{conn: conn} = ctx do
      conn = conn |> log_in(ctx.manager) |> get(~p"/api/users/#{ctx.outsider}")
      assert json_response(conn, 403)
    end

    test "403 for an id outside the organization, 404 for a malformed one",
         %{conn: conn, admin: admin} do
      conn = log_in(conn, admin)
      # A missing id is outside the administrator's organization, like an id of
      # another organization: same answer, so ids cannot be enumerated.
      assert json_response(get(conn, ~p"/api/users/0"), 403)
      assert json_response(get(conn, ~p"/api/users/not-an-id"), 404)
    end
  end

  describe "create" do
    test "an administrator creates an account with a role", %{conn: conn, admin: admin} do
      attrs = %{
        username: "new",
        email: "new@example.com",
        password: valid_password(),
        role: "manager"
      }

      conn = conn |> log_in(admin) |> post(~p"/api/users", user: attrs)

      assert %{"role" => "manager", "email" => "new@example.com"} =
               json_response(conn, 201)["data"]
    end

    test "anyone else gets 403", %{conn: conn, manager: manager} do
      attrs = %{username: "new", email: "new@example.com", password: valid_password()}
      conn = conn |> log_in(manager) |> post(~p"/api/users", user: attrs)
      assert json_response(conn, 403)
    end

    test "invalid data: 422", %{conn: conn, admin: admin} do
      conn = conn |> log_in(admin) |> post(~p"/api/users", user: %{username: nil})
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update" do
    test "a user edits their own profile", %{conn: conn, member: member} do
      conn = conn |> log_in(member) |> put(~p"/api/users/#{member}", user: %{username: "renamed"})
      assert json_response(conn, 200)["data"]["username"] == "renamed"
    end

    test "a role sent in the profile is ignored (mass assignment)", %{conn: conn, member: member} do
      conn =
        conn
        |> log_in(member)
        |> put(~p"/api/users/#{member}", user: %{role: "administrator", role_id: 3})

      assert json_response(conn, 200)["data"]["role"] == "employee"
    end

    test "a manager cannot edit a team member's profile", %{conn: conn} = ctx do
      conn =
        conn |> log_in(ctx.manager) |> put(~p"/api/users/#{ctx.member}", user: %{username: "x"})

      assert json_response(conn, 403)
    end

    test "changing your own password requires the current one", %{conn: conn, member: member} do
      conn = log_in(conn, member)

      wrong =
        put(conn, ~p"/api/users/#{member}",
          user: %{password: "new password!", current_password: "nope"}
        )

      assert %{"current_password" => _} = json_response(wrong, 422)["errors"]

      ok =
        put(conn, ~p"/api/users/#{member}",
          user: %{password: "new password!", current_password: valid_password()}
        )

      assert json_response(ok, 200)
      assert {:ok, _} = TimeManager.Accounts.authenticate(member.email, "new password!")
    end

    test "an administrator resets a password without the old one", %{conn: conn} = ctx do
      conn =
        conn
        |> log_in(ctx.admin)
        |> put(~p"/api/users/#{ctx.member}", user: %{password: "reset password"})

      assert json_response(conn, 200)
      assert {:ok, _} = TimeManager.Accounts.authenticate(ctx.member.email, "reset password")
    end

    test "invalid data: 422; missing user: 403", %{conn: conn, admin: admin} do
      conn = log_in(conn, admin)
      assert json_response(put(conn, ~p"/api/users/#{admin}", user: %{email: "bad"}), 422)
      assert json_response(put(conn, ~p"/api/users/0", user: %{username: "x"}), 403)
    end
  end

  describe "update_role" do
    test "an administrator promotes and demotes", %{conn: conn, admin: admin, member: member} do
      conn = log_in(conn, admin)
      promoted = put(conn, ~p"/api/users/#{member}/role", role: "manager")
      assert json_response(promoted, 200)["data"]["role"] == "manager"

      demoted = put(conn, ~p"/api/users/#{member}/role", role: "employee")
      assert json_response(demoted, 200)["data"]["role"] == "employee"
    end

    test "nobody changes their own role", %{conn: conn} = ctx do
      for user <- [ctx.member, ctx.manager, ctx.admin] do
        conn = conn |> log_in(user) |> put(~p"/api/users/#{user}/role", role: "administrator")
        assert json_response(conn, 403)
      end
    end

    test "a manager cannot promote anyone", %{conn: conn} = ctx do
      conn =
        conn |> log_in(ctx.manager) |> put(~p"/api/users/#{ctx.member}/role", role: "manager")

      assert json_response(conn, 403)
    end

    test "unknown role: 422", %{conn: conn, admin: admin, member: member} do
      conn = conn |> log_in(admin) |> put(~p"/api/users/#{member}/role", role: "superuser")
      assert json_response(conn, 422)
    end
  end

  describe "delete" do
    test "an administrator deletes a user, with their clocks", %{
      conn: conn,
      admin: admin,
      member: member
    } do
      {:ok, _} =
        TimeManager.Clocks.create_clock(member, %{time: ~U[2026-09-28 09:00:00Z], status: true})

      conn = conn |> log_in(admin) |> delete(~p"/api/users/#{member}")
      assert response(conn, 204)
    end

    test "employees and managers delete their own account with their password",
         %{conn: conn} = ctx do
      for user <- [ctx.member, ctx.manager] do
        result =
          conn
          |> log_in(user)
          |> delete(~p"/api/users/#{user}", current_password: valid_password())

        assert response(result, 204)
        assert result.resp_cookies["jwt"].max_age == 0
        assert {:error, :not_found} = TimeManager.Accounts.fetch_user(user.id)
      end
    end

    test "missing or incorrect passwords leave the user and session intact", %{
      conn: conn,
      member: member
    } do
      for password <- [nil, "incorrect password"] do
        result =
          conn
          |> log_in(member)
          |> delete(~p"/api/users/#{member}", current_password: password)

        assert json_response(result, 422)["errors"]["current_password"]
        assert {:ok, _} = TimeManager.Accounts.fetch_user(member.id)
        refute Map.has_key?(result.resp_cookies, "jwt")
      end
    end

    test "an employee cannot delete a colleague and a manager cannot delete a team member",
         %{conn: conn} = ctx do
      assert json_response(
               conn
               |> log_in(ctx.member)
               |> delete(~p"/api/users/#{ctx.outsider}", current_password: valid_password()),
               403
             )

      assert json_response(
               conn
               |> log_in(ctx.manager)
               |> delete(~p"/api/users/#{ctx.member}", current_password: valid_password()),
               403
             )

      assert {:ok, _} = TimeManager.Accounts.fetch_user(ctx.member.id)
    end

    test "deletion cascades working records and a JWT for the deleted account no longer authenticates",
         %{conn: conn, member: member} do
      {:ok, clock} =
        TimeManager.Clocks.create_clock(member, %{time: ~U[2026-09-28 09:00:00Z], status: true})

      {:ok, period} =
        TimeManager.WorkingTimes.create_working_time(member.id, %{
          start: ~U[2026-09-28 09:00:00Z],
          end: ~U[2026-09-28 10:00:00Z]
        })

      logged = log_in(conn, member)

      assert response(
               delete(logged, ~p"/api/users/#{member}", current_password: valid_password()),
               204
             )

      assert TimeManager.Repo.get(TimeManager.Clocks.Clock, clock.id) == nil
      assert TimeManager.Repo.get(TimeManager.WorkingTimes.WorkingTime, period.id) == nil
      assert json_response(get(logged, ~p"/api/auth/me"), 401)
    end

    test "the last administrator cannot be deleted: 409", %{conn: conn, admin: admin} do
      conn =
        conn
        |> log_in(admin)
        |> delete(~p"/api/users/#{admin}", current_password: valid_password())

      assert json_response(conn, 409)
    end
  end

  test "roles are listed read-only", %{conn: conn, member: member} do
    conn = conn |> log_in(member) |> get(~p"/api/roles")

    assert ["employee", "manager", "administrator"] ==
             Enum.map(json_response(conn, 200)["data"], & &1["name"])
  end
end
