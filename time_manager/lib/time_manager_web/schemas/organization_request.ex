defmodule TimeManagerWeb.Schemas.OrganizationRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.Profile

  OpenApiSpex.schema(%{
    title: "OrganizationRequest",
    description: "A new organization and its administrator. No role is read.",
    type: :object,
    properties: %{
      name: %Schema{type: :string, minLength: 2, maxLength: 100, example: "Atelier Gotham"},
      profile: Profile,
      password: %Schema{
        type: :string,
        format: :password,
        minLength: 8,
        maxLength: 128,
        example: "correct horse battery"
      }
    },
    required: [:name, :profile, :password]
  })
end
