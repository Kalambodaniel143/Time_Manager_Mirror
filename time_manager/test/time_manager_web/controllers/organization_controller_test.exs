defmodule TimeManagerWeb.OrganizationControllerTest do
  use TimeManagerWeb.ConnCase, async: true

  import TimeManager.AccountsFixtures

  describe "public creation is disabled" do
    test "cannot create an organization or privileged account", %{conn: conn} do
      conn =
        post(conn, ~p"/api/organizations", %{
          name: "Gotham City",
          profile: %{first_name: "A", last_name: "B", email: "new@example.com"},
          password: valid_password()
        })

      assert json_response(conn, 403)["errors"]["detail"] =~ "désactivée"
      assert {:error, _} = TimeManager.Organizations.lookup_organization("Gotham City")
      assert TimeManager.Accounts.list_users(%{"email" => "new@example.com"}) == []
    end
  end

  describe "lookup" do
    test "finds the exact normalized name and returns only id and name", %{conn: conn} do
      admin = organization_admin_fixture(name: "Atelier Gotham")
      conn = get(conn, ~p"/api/organizations/lookup?name=atelier%20gotham")

      assert json_response(conn, 200)["data"] == %{
               "id" => admin.organization_id,
               "name" => "Atelier Gotham"
             }
    end

    test "is not an approximate search: 404 with a message", %{conn: conn} do
      organization_admin_fixture(name: "Atelier Gotham")
      conn = get(conn, ~p"/api/organizations/lookup?name=Atelier")
      assert json_response(conn, 404)["errors"]["detail"] =~ "Vérifiez"
    end
  end

  describe "members" do
    setup do
      admin = organization_admin_fixture()
      employee = user_fixture(organization_id: admin.organization_id)
      other_admin = organization_admin_fixture()
      %{admin: admin, employee: employee, other_admin: other_admin}
    end

    test "the administrator lists the members, with their personal details",
         %{conn: conn} = ctx do
      conn =
        conn
        |> log_in(ctx.admin)
        |> get(~p"/api/organizations/#{ctx.admin.organization_id}/members")

      members = json_response(conn, 200)["data"]

      assert Enum.sort(Enum.map(members, & &1["id"])) ==
               Enum.sort([ctx.admin.id, ctx.employee.id])

      assert Enum.all?(members, &Map.has_key?(&1, "birth_date"))
    end

    test "403 for an employee, for another organization's administrator, and for a made-up id",
         %{conn: conn} = ctx do
      path = ~p"/api/organizations/#{ctx.admin.organization_id}/members"

      assert json_response(conn |> log_in(ctx.employee) |> get(path), 403)
      assert json_response(conn |> log_in(ctx.other_admin) |> get(path), 403)

      made_up = ~p"/api/organizations/#{Ecto.UUID.generate()}/members"
      assert json_response(conn |> log_in(ctx.admin) |> get(made_up), 403)
    end

    test "promotes an employee to manager and back; the new role applies at once",
         %{conn: conn} = ctx do
      path = ~p"/api/organizations/#{ctx.admin.organization_id}/members/#{ctx.employee.id}"
      admin_conn = log_in(conn, ctx.admin)

      assert json_response(patch(admin_conn, path, role: "manager"), 200)["data"]["role"] ==
               "manager"

      session = conn |> log_in(ctx.employee) |> get(~p"/api/auth/session")
      assert json_response(session, 200)["data"]["role"] == "manager"

      assert json_response(patch(admin_conn, path, role: "employee"), 200)["data"]["role"] ==
               "employee"
    end

    test "only employee and manager; never on an administrator; never self-promotion",
         %{conn: conn} = ctx do
      org = ctx.admin.organization_id
      admin_conn = log_in(conn, ctx.admin)

      assert json_response(
               patch(admin_conn, ~p"/api/organizations/#{org}/members/#{ctx.employee.id}",
                 role: "administrator"
               ),
               422
             )

      assert json_response(
               patch(admin_conn, ~p"/api/organizations/#{org}/members/#{ctx.admin.id}",
                 role: "employee"
               ),
               403
             )

      self_promotion =
        conn
        |> log_in(ctx.employee)
        |> patch(~p"/api/organizations/#{org}/members/#{ctx.employee.id}", role: "manager")

      assert json_response(self_promotion, 403)
    end

    test "a user of another organization is not a member: 404", %{conn: conn} = ctx do
      conn =
        conn
        |> log_in(ctx.admin)
        |> patch(
          ~p"/api/organizations/#{ctx.admin.organization_id}/members/#{ctx.other_admin.id}",
          role: "manager"
        )

      assert json_response(conn, 404)
    end
  end
end
