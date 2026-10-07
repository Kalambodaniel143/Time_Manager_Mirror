defmodule TimeManagerWeb.Schemas.OrganizationLookupResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "OrganizationLookupResponse",
    description: "Only the id and the name of the organization",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          id: %Schema{type: :string, format: :uuid},
          name: %Schema{type: :string, example: "Atelier Gotham"}
        },
        required: [:id, :name]
      }
    },
    required: [:data]
  })
end
