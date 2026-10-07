defmodule TimeManagerWeb.Schemas.JoinRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.Profile

  OpenApiSpex.schema(%{
    title: "JoinRequest",
    description: "A request as the organization's administrators see it (no reference)",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      organization_id: %Schema{type: :string, format: :uuid},
      organization_name: %Schema{type: :string},
      profile: Profile,
      status: %Schema{type: :string, enum: ["pending", "approved", "rejected"]},
      created_at: %Schema{type: :string, format: :"date-time"},
      reviewed_at: %Schema{type: :string, format: :"date-time", nullable: true},
      reviewed_by: %Schema{type: :integer, nullable: true, description: "Reviewer's user ID"},
      rejection_reason: %Schema{type: :string, nullable: true}
    },
    required: [:id, :organization_id, :profile, :status]
  })
end
