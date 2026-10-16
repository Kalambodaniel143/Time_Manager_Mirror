defmodule TimeManagerWeb.Schemas.RolesResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "RolesResponse",
    description: "The predefined roles (read-only)",
    type: :object,
    properties: %{
      data: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{id: %Schema{type: :integer}, name: %Schema{type: :string}}
        }
      }
    },
    example: %{
      "data" => [
        %{"id" => 1, "name" => "employee"},
        %{"id" => 2, "name" => "manager"},
        %{"id" => 3, "name" => "administrator"}
      ]
    }
  })
end
