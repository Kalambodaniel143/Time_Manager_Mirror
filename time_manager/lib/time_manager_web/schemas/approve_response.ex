defmodule TimeManagerWeb.Schemas.ApproveResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.{JoinRequest, User}

  OpenApiSpex.schema(%{
    title: "ApproveResponse",
    description: "The approved request and the employee created. The password is not returned.",
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
