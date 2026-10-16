defmodule TimeManagerWeb.Schemas.JoinRequestCreateRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.Profile

  OpenApiSpex.schema(%{
    title: "JoinRequestCreateRequest",
    description: "A request to join an organization. No password: the administrator sets it.",
    type: :object,
    properties: %{
      organization_id: %Schema{type: :string, format: :uuid},
      profile: Profile
    },
    required: [:organization_id, :profile]
  })
end
