defmodule TimeManagerWeb.SessionRestoreTest do
  use TimeManagerWeb.ConnCase, async: true
  import TimeManager.AccountsFixtures
  alias TimeManager.{Accounts, Token}

  setup do
    user = user_fixture()
    {:ok, jwt, _} = Token.sign(user, "original-csrf")
    %{user: user, jwt: jwt}
  end

  defp fresh_tab(jwt) do
    build_conn()
    |> put_req_cookie("jwt", jwt)
    |> put_req_header("x-session-restore", "1")
  end

  test "a fresh tab restores the current CSRF from its valid cookie without rotating it", ctx do
    conn = fresh_tab(ctx.jwt) |> get(~p"/api/auth/session")
    assert json_response(conn, 200)["data"]["csrf_token"] == "original-csrf"
    assert json_response(conn, 200)["data"]["user"]["id"] == ctx.user.id
    assert get_resp_header(conn, "cache-control") == ["no-store"]
    refute Map.has_key?(conn.resp_cookies, "jwt")

    assert json_response(
             build_conn() |> put_req_cookie("jwt", ctx.jwt) |> get(~p"/api/auth/session"),
             401
           )

    assert json_response(
             build_conn()
             |> put_req_header("x-session-restore", "1")
             |> get(~p"/api/auth/session"),
             401
           )
  end

  test "only GET session restoration accepts the custom header instead of a CSRF token", ctx do
    assert json_response(fresh_tab(ctx.jwt) |> get(~p"/api/auth/me"), 401)
    assert json_response(fresh_tab(ctx.jwt) |> post(~p"/api/auth/logout"), 401)

    assert json_response(
             fresh_tab(ctx.jwt)
             |> put(~p"/api/users/#{ctx.user.id}", user: %{first_name: "Changed"}),
             401
           )

    assert json_response(
             fresh_tab(ctx.jwt) |> post(~p"/api/clocks/#{ctx.user.id}", clock: %{status: true}),
             401
           )
  end

  test "cross-origin fetch metadata cannot use restoration", ctx do
    for site <- ["cross-site", "same-site"] do
      conn =
        fresh_tab(ctx.jwt) |> put_req_header("sec-fetch-site", site) |> get(~p"/api/auth/session")

      assert json_response(conn, 401)
    end
  end

  test "a stale CSRF after a same-account login can be refreshed, then used normally", ctx do
    {:ok, newer, _} = Token.sign(ctx.user, "new-csrf")

    conn =
      fresh_tab(newer)
      |> put_req_header("x-csrf-token", "original-csrf")
      |> get(~p"/api/auth/session")

    csrf = json_response(conn, 200)["data"]["csrf_token"]
    assert csrf == "new-csrf"

    assert json_response(
             build_conn()
             |> put_req_cookie("jwt", newer)
             |> put_req_header("x-csrf-token", csrf)
             |> get(~p"/api/auth/me"),
             200
           )

    assert json_response(
             build_conn()
             |> put_req_cookie("jwt", newer)
             |> put_req_header("x-csrf-token", "original-csrf")
             |> get(~p"/api/auth/me"),
             401
           )
  end

  test "revocation and password changes still prevent restoration", ctx do
    {:ok, claims} = Token.verify_and_validate(ctx.jwt)
    assert :ok = Accounts.revoke_session(claims)
    assert json_response(fresh_tab(ctx.jwt) |> get(~p"/api/auth/session"), 401)
    {:ok, second, _} = Token.sign(ctx.user, "another-csrf")
    assert {:ok, _} = Accounts.reset_password(ctx.user, %{password: "my new personal phrase"})
    assert json_response(fresh_tab(second) |> get(~p"/api/auth/session"), 401)
  end
end
