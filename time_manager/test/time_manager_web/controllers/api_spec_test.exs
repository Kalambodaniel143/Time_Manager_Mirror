defmodule TimeManagerWeb.ApiSpecTest do
  use TimeManagerWeb.ConnCase, async: true

  test "the OpenAPI spec is public and documents the auth routes", %{conn: conn} do
    spec = conn |> get(~p"/api/openapi") |> json_response(200)

    for path <- [
          "/api/auth/login",
          "/api/auth/me",
          "/api/teams",
          "/api/users/{id}/role",
          "/api/roles"
        ] do
      assert Map.has_key?(spec["paths"], path), "missing #{path}"
    end

    assert spec["components"]["securitySchemes"]["csrfToken"]["name"] == "X-CSRF-Token"
    assert spec["paths"]["/api/auth/login"]["post"]["security"] == []
  end
end
