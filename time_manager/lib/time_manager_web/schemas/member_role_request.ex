defmodule TimeManagerWeb.Schemas.MemberRoleRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "MemberRoleRequest",
    description: "New role of a member: employee or manager only",
    type: :object,
    properties: %{
      role: %Schema{type: :string, enum: ["employee", "manager"]}
    },
    required: [:role]
  })
end
