defmodule TimeManagerWeb.UserControllerTest do
  use TimeManagerWeb.ConnCase

  import TimeManager.AccountsFixtures
  alias TimeManager.Accounts.User

  @create_attrs %{
    username: "some username",
    email: "some email"
  }
  @update_attrs %{
    username: "some updated username",
    email: "some updated email"
  }
  @invalid_attrs %{username: nil, email: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "lists all users", %{conn: conn} do
      conn = get(conn, ~p"/api/users")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create user" do
    test "renders user when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/api/users", user: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, ~p"/api/users/#{id}")

      assert %{
               "id" => ^id,
               "email" => "some email",
               "username" => "some username"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/api/users", user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update user" do
    setup [:create_user]

    test "renders user when data is valid", %{conn: conn, user: %User{id: id} = user} do
      conn = put(conn, ~p"/api/users/#{user}", user: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, ~p"/api/users/#{id}")

      assert %{
               "id" => ^id,
               "email" => "some updated email",
               "username" => "some updated username"
             } = json_response(conn, 200)["data"]
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, ~p"/api/users/#{user}", user: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete user" do
    setup [:create_user]

    test "deletes chosen user", %{conn: conn, user: user} do
      conn = delete(conn, ~p"/api/users/#{user}")
      assert response(conn, 204)

      conn = get(conn, ~p"/api/users/#{user}")
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  describe "not found" do
    test "show renders 404 for a missing id", %{conn: conn} do
      conn = get(conn, ~p"/api/users/0")
      assert json_response(conn, 404)["errors"] != %{}
    end

    test "show renders 404 for a malformed id", %{conn: conn} do
      conn = get(conn, ~p"/api/users/not-an-id")
      assert json_response(conn, 404)["errors"] != %{}
    end

    test "update renders 404 for a missing id", %{conn: conn} do
      conn = put(conn, ~p"/api/users/0", user: @update_attrs)
      assert json_response(conn, 404)["errors"] != %{}
    end

    test "delete renders 404 for a missing id", %{conn: conn} do
      conn = delete(conn, ~p"/api/users/0")
      assert json_response(conn, 404)["errors"] != %{}
    end
  end

  defp create_user(_) do
    user = user_fixture()

    %{user: user}
  end
end
