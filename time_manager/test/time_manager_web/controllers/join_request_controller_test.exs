defmodule TimeManagerWeb.JoinRequestControllerTest do
  use TimeManagerWeb.ConnCase, async: true

  import TimeManager.AccountsFixtures

  alias TimeManager.Accounts

  setup do
    admin = organization_admin_fixture(name: "Atelier Gotham")
    %{admin: admin, org: admin.organization_id}
  end

  describe "submit" do
    test "records a pending request, without account nor session", %{conn: conn, org: org} do
      profile = join_profile(%{"email" => " Sara@Example.com "})
      conn = post(conn, ~p"/api/join-requests", organization_id: org, profile: profile)

      assert %{
               "id" => _,
               "reference" => reference,
               "organization_name" => "Atelier Gotham",
               "status" => "pending"
             } = data = json_response(conn, 201)["data"]

      assert byte_size(reference) >= 40
      refute Map.has_key?(data, "rejection_reason")
      refute conn.resp_cookies["jwt"]
      assert Accounts.list_users(%{"email" => "sara@example.com"}) == []
    end

    test "personal details are required and validated", %{conn: conn, org: org} do
      profile = %{
        "first_name" => "Sara",
        "last_name" => "Martin",
        "email" => unique_email(),
        "gender" => "other",
        "birth_date" => Date.utc_today() |> Date.add(1) |> Date.to_iso8601()
      }

      conn = post(conn, ~p"/api/join-requests", organization_id: org, profile: profile)

      assert %{"gender" => _, "birth_date" => _, "birth_place" => _} =
               json_response(conn, 422)["errors"]
    end

    test "an unknown organization is a 404", %{conn: conn} do
      for id <- [Ecto.UUID.generate(), "not-a-uuid"] do
        conn = post(conn, ~p"/api/join-requests", organization_id: id, profile: join_profile())
        assert json_response(conn, 404)
      end
    end

    test "409 for an e-mail with an account, and for a second pending request",
         %{conn: conn, admin: admin, org: org} do
      taken =
        post(conn, ~p"/api/join-requests",
          organization_id: org,
          profile: join_profile(%{"email" => admin.email})
        )

      assert %{"email" => _} = json_response(taken, 409)["errors"]

      profile = join_profile()

      assert json_response(
               post(conn, ~p"/api/join-requests", organization_id: org, profile: profile),
               201
             )

      assert json_response(
               post(conn, ~p"/api/join-requests", organization_id: org, profile: profile),
               409
             )
    end
  end

  describe "status" do
    test "follows the request with its reference, without exposing the profile",
         %{conn: conn, org: org} do
      {request, reference} = join_request_fixture(org)
      conn = post(conn, ~p"/api/join-requests/status", reference: reference)

      assert json_response(conn, 200)["data"] == %{
               "id" => request.id,
               "reference" => reference,
               "organization_name" => "Atelier Gotham",
               "status" => "pending",
               "rejection_reason" => nil
             }
    end

    test "an unknown reference is a 404", %{conn: conn} do
      assert json_response(post(conn, ~p"/api/join-requests/status", reference: "guess"), 404)
    end
  end

  describe "review" do
    setup %{admin: admin, org: org} do
      {request, reference} = join_request_fixture(org, %{"email" => "sara@example.com"})
      %{request: request, reference: reference, admin_conn: log_in(build_conn(), admin)}
    end

    test "the administrator lists the requests, without their reference", ctx do
      conn = get(ctx.admin_conn, ~p"/api/organizations/#{ctx.org}/join-requests")

      assert [
               %{"id" => id, "profile" => %{"email" => "sara@example.com"}, "status" => "pending"} =
                 request
             ] =
               json_response(conn, 200)["data"]

      assert id == ctx.request.id
      refute Map.has_key?(request, "reference")
      refute response(conn, 200) =~ ctx.reference
    end

    test "approval creates the employee with the administrator's password", ctx do
      path = ~p"/api/organizations/#{ctx.org}/join-requests/#{ctx.request.id}/approve"
      conn = post(ctx.admin_conn, path, password: "chosen by admin")

      assert %{"request" => request, "user" => user} = json_response(conn, 200)["data"]
      assert request["status"] == "approved"
      assert request["reviewed_by"] == ctx.admin.id
      assert user["role"] == "employee"
      assert user["organization_id"] == ctx.org
      assert user["username"] == "sara@example.com"
      assert user["birth_place"] == "Paris"
      refute response(conn, 200) =~ "chosen by admin"

      assert {:ok, _} = Accounts.authenticate("sara@example.com", "chosen by admin")

      status = post(build_conn(), ~p"/api/join-requests/status", reference: ctx.reference)
      assert json_response(status, 200)["data"]["status"] == "approved"

      assert json_response(post(ctx.admin_conn, path, password: "chosen by admin"), 409)
    end

    test "an invalid password leaves the request pending and creates nothing", ctx do
      path = ~p"/api/organizations/#{ctx.org}/join-requests/#{ctx.request.id}/approve"
      conn = post(ctx.admin_conn, path, password: "short")

      assert %{"password" => _} = json_response(conn, 422)["errors"]
      assert Accounts.list_users(%{"email" => "sara@example.com"}) == []

      status = post(build_conn(), ~p"/api/join-requests/status", reference: ctx.reference)
      assert json_response(status, 200)["data"]["status"] == "pending"
    end

    test "rejection with a reason; the applicant may then try again", ctx do
      path = ~p"/api/organizations/#{ctx.org}/join-requests/#{ctx.request.id}/reject"

      assert %{"reason" => _} =
               json_response(post(ctx.admin_conn, path, reason: "   "), 422)["errors"]

      conn = post(ctx.admin_conn, path, reason: "  Autre organisation.  ")

      assert %{"status" => "rejected", "rejection_reason" => "Autre organisation."} =
               json_response(conn, 200)["data"]

      status = post(build_conn(), ~p"/api/join-requests/status", reference: ctx.reference)
      assert json_response(status, 200)["data"]["rejection_reason"] == "Autre organisation."

      assert json_response(post(ctx.admin_conn, path, reason: "Encore"), 409)
      assert Accounts.list_users(%{"email" => "sara@example.com"}) == []

      again =
        post(build_conn(), ~p"/api/join-requests",
          organization_id: ctx.org,
          profile: join_profile(%{"email" => "sara@example.com"})
        )

      assert json_response(again, 201)
    end

    test "only an administrator of this organization reviews", ctx do
      path = ~p"/api/organizations/#{ctx.org}/join-requests/#{ctx.request.id}/approve"
      manager = user_fixture(role: "manager", organization_id: ctx.org)
      other_admin = organization_admin_fixture()

      for user <- [manager, other_admin] do
        conn = build_conn() |> log_in(user) |> post(path, password: valid_password())
        assert json_response(conn, 403)
      end

      # Even through their own organization's URL, another organization's request is unknown.
      other_path =
        ~p"/api/organizations/#{other_admin.organization_id}/join-requests/#{ctx.request.id}/approve"

      conn = build_conn() |> log_in(other_admin) |> post(other_path, password: valid_password())
      assert json_response(conn, 404)
    end
  end
end
