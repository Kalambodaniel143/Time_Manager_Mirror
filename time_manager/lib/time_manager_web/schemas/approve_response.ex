defmodule TimeManagerWeb.Schemas.ApproveResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.{JoinRequest, User}

  OpenApiSpex.schema(%{
    title: "ApproveResponse",
    description:
      "The approved request and the configured member. The password is never returned by the API.",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{request: JoinRequest, user: User},
        required: [:request, :user]
      }
    },
    required: [:data]
  })
end
