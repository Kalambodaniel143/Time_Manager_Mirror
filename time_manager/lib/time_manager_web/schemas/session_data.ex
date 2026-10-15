defmodule TimeManagerWeb.Schemas.SessionData do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.{Organization, User}

  OpenApiSpex.schema(%{
    title: "SessionData",
    description:
      "The current session. role equals user.role; organization is null for an account " <>
        "without organization.",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          role: %Schema{type: :string, enum: ["employee", "manager", "administrator"]},
          csrf_token: %Schema{type: :string, description: "Token bound to the current JWT cookie"},
          user: User,
          organization: %Schema{allOf: [Organization], nullable: true}
        },
        required: [:role, :user, :organization, :csrf_token]
      }
    },
    required: [:data]
  })
end
