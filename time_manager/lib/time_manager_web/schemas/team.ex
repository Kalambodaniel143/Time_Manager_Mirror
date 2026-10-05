defmodule TimeManagerWeb.Schemas.Team do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.User

  OpenApiSpex.schema(%{
    title: "Team",
    description: "A team, its manager and its members",
    type: :object,
    properties: %{
      id: %Schema{type: :integer, example: 1},
      name: %Schema{type: :string, example: "Voirie nuit"},
      manager: %Schema{allOf: [User], nullable: true},
      members: %Schema{type: :array, items: User}
    },
    required: [:id, :name, :members]
  })
end
