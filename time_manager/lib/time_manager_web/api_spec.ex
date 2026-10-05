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
          "API for managing users, teams, their clock-ins/outs and their working times. " <>
            "Authentication: JWT in an HttpOnly cookie plus an X-CSRF-Token header.",
        version: "1.0.0"
      },
      paths: Paths.from_router(TimeManagerWeb.Router),
      # Both are required on every route except login and register. In Swagger UI,
      # log in first (the browser stores the cookie), then paste csrf_token under
      # "Authorize".
      components: %Components{
        securitySchemes: %{
          "jwtCookie" => %SecurityScheme{type: "apiKey", in: "cookie", name: "jwt"},
          "csrfToken" => %SecurityScheme{type: "apiKey", in: "header", name: "X-CSRF-Token"}
        }
      },
      security: [%{"jwtCookie" => [], "csrfToken" => []}]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
