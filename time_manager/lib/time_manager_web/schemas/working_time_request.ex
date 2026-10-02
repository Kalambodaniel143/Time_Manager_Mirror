defmodule TimeManagerWeb.Schemas.WorkingTimeRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "WorkingTimeRequest",
    description:
      "Request body to create or update a working time slot. `end` must be after `start`.",
    type: :object,
    properties: %{
      workingtime: %Schema{
        type: :object,
        properties: %{
          start: %Schema{
            type: :string,
            format: :"date-time",
            description: "ISO 8601 UTC timestamp",
            example: "2026-09-22T08:00:00Z"
          },
          end: %Schema{
            type: :string,
            format: :"date-time",
            description: "ISO 8601 UTC timestamp, must be after start",
            example: "2026-09-22T17:00:00Z"
          }
        },
        required: [:start, :end]
      }
    },
    required: [:workingtime],
    example: %{
      "workingtime" => %{
        "start" => "2026-09-22T08:00:00Z",
        "end" => "2026-09-22T17:00:00Z"
      }
    }
  })
end
