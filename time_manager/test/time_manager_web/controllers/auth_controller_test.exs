defmodule TimeManagerWeb.AuthControllerTest do
  use TimeManagerWeb.ConnCase, async: true

  import TimeManager.AccountsFixtures

  setup do
    %{user: user_fixture(email: "agent@example.com")}
  end

  describe "login" do
    test "sets an HttpOnly cookie and returns the CSRF token", %{conn: conn, user: user} do
      conn = post(conn, ~p"/api/auth/login", email: user.email, password: valid_password())

      assert %{"csrf_token" => csrf, "user" => %{"id" => id, "role" => "employee"}} =
               json_response(conn, 200)["data"]

      assert id == user.id
      assert is_binary(csrf) and byte_size(csrf) >= 32

      cookie = conn.resp_cookies["jwt"]
      assert cookie.http_only
      assert cookie.same_site == "Strict"
      refute Map.has_key?(json_response(conn, 200)["data"], "jwt")
    end

    test "the cookie and the CSRF token open a session", %{conn: conn, user: user} do
      login = post(conn, ~p"/api/auth/login", email: user.email, password: valid_password())
      csrf = json_response(login, 200)["data"]["csrf_token"]

      me =
        build_conn()
        |> put_req_cookie("jwt", login.resp_cookies["jwt"].value)
        |> put_req_header("x-csrf-token", csrf)
        |> get(~p"/api/auth/me")

      assert json_response(me, 200)["data"]["id"] == user.id
    end

    test "one message for a wrong password and an unknown e-mail", %{conn: conn, user: user} do
      wrong = post(conn, ~p"/api/auth/login", email: user.email, password: "wrong password")
      unknown = post(conn, ~p"/api/auth/login", email: "x@example.com", password: "whatever1")

      assert json_response(wrong, 401) == json_response(unknown, 401)
      assert json_response(wrong, 401)["errors"]["detail"] == "Invalid credentials"
      refute wrong.resp_cookies["jwt"]
    end

    test "never returns the password hash", %{conn: conn, user: user} do
      conn = post(conn, ~p"/api/auth/login", email: user.email, password: valid_password())
      refute response(conn, 200) =~ "password"
    end
  end

  describe "authentication of protected routes" do
    test "no cookie: 401", %{conn: conn} do
      conn = get(conn, ~p"/api/auth/me")
      assert json_response(conn, 401)["errors"]["detail"] == "Unauthorized"
    end

    test "cookie without the CSRF header: 401 (a forged cross-site request)", %{user: user} do
      {:ok, jwt, _} = TimeManager.Token.sign(user, "the-real-token")
      conn = build_conn() |> put_req_cookie("jwt", jwt) |> get(~p"/api/auth/me")
      assert json_response(conn, 401)
    end

    test "CSRF header that does not match the JWT: 401", %{user: user} do
      {:ok, jwt, _} = TimeManager.Token.sign(user, "the-real-token")

      conn =
        build_conn()
        |> put_req_cookie("jwt", jwt)
        |> put_req_header("x-csrf-token", "a-guessed-token")
        |> get(~p"/api/auth/me")

      assert json_response(conn, 401)
    end

    test "tampered or expired JWT: 401", %{user: user} do
      {:ok, jwt, _} = TimeManager.Token.sign(user, "csrf")
      [header, _payload, signature] = String.split(jwt, ".")

      forged =
        Base.url_encode64(~s({"user_id":#{user.id},"role":"administrator","xsrf":"csrf"}),
          padding: false
        )

      tampered =
        build_conn()
        |> put_req_cookie("jwt", Enum.join([header, forged, signature], "."))
        |> put_req_header("x-csrf-token", "csrf")
        |> get(~p"/api/auth/me")

      assert json_response(tampered, 401)

      expired_claims = %{"user_id" => user.id, "role" => "employee", "xsrf" => "csrf", "exp" => 1}

      {:ok, expired, _} =
        Joken.encode_and_sign(
          expired_claims,
          Joken.Signer.create("HS256", Application.fetch_env!(:joken, :default_signer))
        )

      expired_conn =
        build_conn()
        |> put_req_cookie("jwt", expired)
        |> put_req_header("x-csrf-token", "csrf")
        |> get(~p"/api/auth/me")

      assert json_response(expired_conn, 401)
    end

    test "the role is read from the database: a demotion applies immediately", %{conn: conn} do
      admin = user_fixture(role: "administrator")
      _other_admin = user_fixture(role: "administrator")
      conn = log_in(conn, admin)

      assert json_response(get(conn, ~p"/api/users"), 200)

      {:ok, _} = TimeManager.Accounts.change_role(admin, "employee")
      assert json_response(get(conn, ~p"/api/users"), 403)
    end

    test "a deleted account loses its session", %{conn: conn, user: user} do
      conn = log_in(conn, user)
      {:ok, _} = TimeManager.Accounts.delete_user(user)
      assert json_response(get(conn, ~p"/api/auth/me"), 401)
    end
  end

  describe "register" do
    test "creates an employee and logs in, whatever role is sent", %{conn: conn} do
      attrs = %{
        username: "eve",
        email: "eve@example.com",
        password: valid_password(),
        role: "administrator"
      }

      conn = post(conn, ~p"/api/auth/register", user: attrs)

      assert %{"user" => %{"role" => "employee"}, "csrf_token" => _} =
               json_response(conn, 201)["data"]

      assert conn.resp_cookies["jwt"]
    end

    test "validates the e-mail and the password", %{conn: conn} do
      conn =
        post(conn, ~p"/api/auth/register", user: %{username: "x", email: "bad", password: "123"})

      assert %{"email" => _, "password" => _} = json_response(conn, 422)["errors"]
    end
  end

  describe "login of an organization member" do
    test "returns the session model with the organization", %{conn: conn} do
      admin = organization_admin_fixture(name: "Atelier Gotham")
      conn = post(conn, ~p"/api/auth/login", email: admin.email, password: valid_password())

      assert %{
               "csrf_token" => _,
               "role" => "administrator",
               "user" => %{"role" => "administrator", "organization_id" => org_id},
               "organization" => %{"id" => org_id, "name" => "Atelier Gotham"}
             } = json_response(conn, 200)["data"]
    end

    test "a bcrypt hash from before Argon2 still works and is upgraded", %{conn: conn, user: user} do
      legacy = Bcrypt.hash_pwd_salt(valid_password())
      TimeManager.Repo.update_all(TimeManager.Accounts.User, set: [password_hash: legacy])

      conn = post(conn, ~p"/api/auth/login", email: user.email, password: valid_password())
      assert json_response(conn, 200)

      assert "$argon2id$" <> _ = TimeManager.Accounts.get_user!(user.id).password_hash
    end
  end

  describe "session" do
    test "returns role, user and organization (null without organization)",
         %{conn: conn, user: user} do
      conn = conn |> log_in(user) |> get(~p"/api/auth/session")

      assert %{"role" => "employee", "user" => %{"id" => id}, "organization" => nil} =
               json_response(conn, 200)["data"]

      assert id == user.id
    end

    test "401 without a session, never data: null", %{conn: conn} do
      assert json_response(get(conn, ~p"/api/auth/session"), 401)
    end
  end

  test "logout removes the cookie and revokes the JWT on the server", %{conn: conn, user: user} do
    conn = log_in(conn, user)
    logout = post(conn, ~p"/api/auth/logout")
    assert response(logout, 204)
    assert logout.resp_cookies["jwt"].max_age == 0

    # The same cookie and CSRF token, replayed after the logout.
    assert json_response(get(conn, ~p"/api/auth/session"), 401)
    assert json_response(post(conn, ~p"/api/auth/logout"), 401)
  end

  test "a request from another site is refused, even on a public route", %{conn: conn, user: user} do
    forged =
      conn
      |> put_req_header("origin", "https://evil.example")
      |> post(~p"/api/auth/login", email: user.email, password: valid_password())

    assert json_response(forged, 403)
    refute forged.resp_cookies["jwt"]

    same_site =
      build_conn()
      |> put_req_header("origin", "http://www.example.com:8080")
      |> post(~p"/api/auth/login", email: user.email, password: valid_password())

    assert json_response(same_site, 200)
  end
end
