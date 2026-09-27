defmodule TimeManagerWeb.ApiSpec do
  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{Info, OpenApi, Paths, Server}

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      servers: [Server.from_endpoint(TimeManagerWeb.Endpoint)],
      info: %Info{
        title: "Time Manager API",
        description: "API for managing users, their clock-ins/outs and their working times.",
        version: "1.0.0"
      },
      paths: Paths.from_router(TimeManagerWeb.Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
