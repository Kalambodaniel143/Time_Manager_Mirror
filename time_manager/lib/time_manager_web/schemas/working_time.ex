defmodule TimeManagerWeb.Schemas.WorkingTime do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "WorkingTime",
    description:
      "A recorded working time slot. Note: unlike the request body (ISO 8601), " <>
        "`start`/`end` are rendered here as \"YYYY-MM-DD HH:MM:SS\" (no timezone offset, always UTC).",
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "Working time ID", example: 1},
      start: %Schema{type: :string, example: "2026-09-22 08:00:00"},
      end: %Schema{type: :string, example: "2026-09-22 17:00:00"},
      user_id: %Schema{type: :integer, description: "Owning user's ID", example: 1}
    },
    required: [:id, :start, :end, :user_id]
  })
end
