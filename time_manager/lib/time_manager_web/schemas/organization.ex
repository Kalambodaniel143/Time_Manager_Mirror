defmodule TimeManagerWeb.Schemas.Organization do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Organization",
    description: "An organization",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid, example: "6f1c2a3e-8a0b-4c7e-9f61-2d3b4c5d6e7f"},
      name: %Schema{type: :string, example: "Atelier Gotham"},
      created_at: %Schema{type: :string, format: :"date-time", example: "2026-10-05T12:00:00Z"}
    },
    required: [:id, :name]
  })
end
