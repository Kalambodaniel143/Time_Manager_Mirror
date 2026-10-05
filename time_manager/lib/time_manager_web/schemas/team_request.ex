defmodule TimeManagerWeb.Schemas.TeamRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "TeamRequest",
    description: "Create or update a team. The manager must have the manager role.",
    type: :object,
    properties: %{
      team: %Schema{
        type: :object,
        properties: %{
          name: %Schema{type: :string, example: "Voirie nuit"},
          manager_id: %Schema{type: :integer, nullable: true, example: 2}
        }
      }
    },
    required: [:team]
  })
end
