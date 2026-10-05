defmodule TimeManagerWeb.Schemas.RoleRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "RoleRequest",
    description: "Promotion or demotion of a user",
    type: :object,
    properties: %{
      role: %Schema{type: :string, enum: ["employee", "manager", "administrator"]}
    },
    required: [:role]
  })
end
