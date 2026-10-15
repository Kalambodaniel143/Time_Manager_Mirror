defmodule TimeManagerWeb.ApiSpec do
  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      servers: [Server.from_endpoint(TimeManagerWeb.Endpoint)],
      info: %Info{
        title: "Time Manager API",
        description:
          "API for accounts, teams, clock events, worked hours, corrections, weekly sheets, planning, swaps, absences, payroll, preferences and notifications. " <>
            "Authentication: JWT in an HttpOnly cookie plus an X-CSRF-Token header.",
        version: "2.0.0"
      },
      paths: Paths.from_router(TimeManagerWeb.Router),
      # Protected routes require both, except read-only session restoration.
      # Public routes override security in their operation specs. In Swagger UI,
      # log in first (the browser stores the cookie), then paste csrf_token under
      # "Authorize".
      components: %Components{
        securitySchemes: %{
          "jwtCookie" => %SecurityScheme{type: "apiKey", in: "cookie", name: "jwt"},
          "sessionRestoreHeader" => %SecurityScheme{
            type: "apiKey",
            in: "header",
            name: "X-Session-Restore",
            description: "Use value 1 only on GET /api/auth/session to restore a fresh tab"
          },
          "csrfToken" => %SecurityScheme{type: "apiKey", in: "header", name: "X-CSRF-Token"}
        }
      },
      security: [%{"jwtCookie" => [], "csrfToken" => []}]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
