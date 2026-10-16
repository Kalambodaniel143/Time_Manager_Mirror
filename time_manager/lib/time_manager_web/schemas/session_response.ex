defmodule TimeManagerWeb.Schemas.SessionResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.{Organization, User}

  OpenApiSpex.schema(%{
    title: "SessionResponse",
    description:
      "Returned at login, registration and organization creation. The JWT itself is in the " <>
        "HttpOnly `jwt` cookie; send csrf_token back in the X-CSRF-Token header of every request.",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          csrf_token: %Schema{type: :string, example: "k3J9..."},
          role: %Schema{type: :string, enum: ["employee", "manager", "administrator"]},
          user: User,
          organization: %Schema{allOf: [Organization], nullable: true}
        },
        required: [:csrf_token, :role, :user, :organization]
      }
    },
    required: [:data]
  })
end
