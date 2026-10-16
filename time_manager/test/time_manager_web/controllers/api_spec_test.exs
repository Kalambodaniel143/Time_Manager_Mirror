defmodule TimeManagerWeb.ApiSpecTest do
  use TimeManagerWeb.ConnCase, async: true

  test "clock response documents a strict UTC text timestamp", %{conn: conn} do
    spec = conn |> get(~p"/api/openapi") |> json_response(200)
    time = spec["components"]["schemas"]["Clock"]["properties"]["time"]
    assert time["type"] == "string"
    refute Map.has_key?(time, "format")
    pattern = Regex.compile!(time["pattern"])
    assert Regex.match?(pattern, "2020-01-02 03:04:05")
    refute Regex.match?(pattern, "2020-01-02T03:04:05Z")
  end

  test "the OpenAPI spec is public and documents the auth routes", %{conn: conn} do
    spec = conn |> get(~p"/api/openapi") |> json_response(200)

    for path <- [
          "/api/auth/login",
          "/api/auth/me",
          "/api/teams",
          "/api/users/{id}/role",
          "/api/roles",
          "/api/auth/session",
          "/api/organizations",
          "/api/organizations/lookup",
          "/api/join-requests",
          "/api/join-requests/status",
          "/api/organizations/{org_id}/join-requests",
          "/api/organizations/{org_id}/join-requests/{id}/approve",
          "/api/organizations/{org_id}/members/{id}"
        ] do
      assert Map.has_key?(spec["paths"], path), "missing #{path}"
    end

    assert spec["components"]["securitySchemes"]["csrfToken"]["name"] == "X-CSRF-Token"

    for {path, method} <- [
          {"/api/auth/login", "post"},
          {"/api/organizations", "post"},
          {"/api/organizations/lookup", "get"},
          {"/api/join-requests", "post"},
          {"/api/join-requests/status", "post"}
        ] do
      assert spec["paths"][path][method]["security"] == [], "#{path} should be public"
    end
  end
end
