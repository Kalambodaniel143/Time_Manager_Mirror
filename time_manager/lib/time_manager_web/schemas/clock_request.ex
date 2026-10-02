defmodule TimeManagerWeb.Schemas.ClockRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ClockRequest",
    description: "Request body to record a clock-in or clock-out for a user",
    type: :object,
    properties: %{
      clock: %Schema{
        type: :object,
        properties: %{
          time: %Schema{
            type: :string,
            format: :"date-time",
            description: "ISO 8601 UTC timestamp",
            example: "2026-09-23T08:00:00Z"
          },
          status: %Schema{
            type: :boolean,
            description: "true = clock-in, false = clock-out",
            example: true
          }
        },
        required: [:time, :status]
      }
    },
    required: [:clock],
    example: %{
      "clock" => %{"time" => "2026-09-23T08:00:00Z", "status" => true}
    }
  })
end
