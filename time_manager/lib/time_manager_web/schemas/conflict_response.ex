defmodule TimeManagerWeb.Schemas.ConflictResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ConflictResponse",
    description: "A conflict (409): a displayable detail, plus the fields concerned",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :object,
        properties: %{detail: %Schema{type: :string}},
        additionalProperties: %Schema{type: :array, items: %Schema{type: :string}}
      }
    },
    example: %{
      "errors" => %{
        "detail" => "Une organisation porte déjà ce nom.",
        "name" => ["Ce nom est déjà utilisé."]
      }
    }
  })
end
