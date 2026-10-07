defmodule TimeManagerWeb.OrganizationControllerTest do
  use TimeManagerWeb.ConnCase, async: true

  import TimeManager.AccountsFixtures

  defp create_body(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Atelier Gotham",
      profile: %{first_name: "Nando", last_name: "Martin", email: "nando@example.com"},
      password: valid_password()
    })
  end

  describe "create" do
    test "creates the organization and its administrator, and opens their session",
         %{conn: conn} do
      conn = post(conn, ~p"/api/organizations", create_body())

      assert %{
               "csrf_token" => csrf,
               "role" => "administrator",
               "user" => %{"role" => "administrator", "organization_id" => org_id} = user,
               "organization" => %{"id" => org_id, "name" => "Atelier Gotham", "created_at" => _}
             } = json_response(conn, 201)["data"]

      assert user["username"] == "nando@example.com"
      assert user["first_name"] == "Nando"
      assert user["gender"] == nil
      assert conn.resp_cookies["jwt"].http_only
      refute response(conn, 201) =~ "password"

      session =
        build_conn()
        |> put_req_cookie("jwt", conn.resp_cookies["jwt"].value)
        |> put_req_header("x-csrf-token", csrf)
        |> get(~p"/api/auth/session")

      assert json_response(session, 200)["data"]["organization"]["id"] == org_id
    end

    test "no role is read from the body", %{conn: conn} do
      body =
        create_body(%{
          role: "employee",
          profile: %{first_name: "A", last_name: "B", email: "a@b.co", role: "employee"}
        })

      conn = post(conn, ~p"/api/organizations", body)
      assert json_response(conn, 201)["data"]["role"] == "administrator"
    end

    test "a name equal but for case, accents and spaces is a 409", %{conn: conn} do
      organization_admin_fixture(name: "Atelier Gotham")

      conn =
        post(conn, ~p"/api/organizations", create_body(%{name: "  ATELIER   Gothàm "}))

      assert %{"detail" => _, "name" => [_]} = json_response(conn, 409)["errors"]
    end

    test "an e-mail already used is a 409 and creates no organization", %{conn: conn} do
      user_fixture(email: "nando@example.com")
      conn = post(conn, ~p"/api/organizations", create_body())

      assert %{"email" => [_]} = json_response(conn, 409)["errors"]
      assert {:error, _} = TimeManager.Organizations.lookup_organization("Atelier Gotham")
    end

    test "reports every invalid field at once; no personal details required", %{conn: conn} do
      body = %{
        name: " x ",
        profile: %{first_name: "  ", last_name: "Martin", email: "bad"},
        password: String.duplicate("a", 129)
      }

      conn = post(conn, ~p"/api/organizations", body)

      assert %{"name" => _, "first_name" => _, "email" => _, "password" => _} =
               errors = json_response(conn, 422)["errors"]

      refute Map.has_key?(errors, "gender")
    end

    test "a 128-character password is kept as typed, spaces included", %{conn: conn} do
      password = " " <> String.duplicate("p", 126) <> " "
      conn = post(conn, ~p"/api/organizations", create_body(%{password: password}))
      assert json_response(conn, 201)

      assert {:ok, _} = TimeManager.Accounts.authenticate("nando@example.com", password)

      assert {:error, _} =
               TimeManager.Accounts.authenticate("nando@example.com", String.trim(password))
    end

    test "a password made of spaces only is refused", %{conn: conn} do
      conn = post(conn, ~p"/api/organizations", create_body(%{password: "          "}))
      assert %{"password" => _} = json_response(conn, 422)["errors"]
    end

    test "a malformed body is a 400", %{conn: conn} do
      assert json_response(post(conn, ~p"/api/organizations", %{name: "X"}), 400)
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
