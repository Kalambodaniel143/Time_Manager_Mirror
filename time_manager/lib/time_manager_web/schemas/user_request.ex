defmodule TimeManagerWeb.Schemas.UserRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "UserRequest",
    description:
      "Request body to create or update a user. Both fields are required on create; " <>
        "on update, an omitted field keeps its current value.",
    type: :object,
    properties: %{
      user: %Schema{
        type: :object,
        properties: %{
          username: %Schema{type: :string, example: "alice"},
          email: %Schema{type: :string, format: :email, example: "alice@example.com"}
        }
      }
    },
    required: [:user],
    example: %{
      "user" => %{"username" => "alice", "email" => "alice@example.com"}
    }
  })
end
