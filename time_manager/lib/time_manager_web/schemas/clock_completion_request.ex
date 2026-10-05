defmodule TimeManagerWeb.Schemas.ClockCompletionRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ClockCompletionRequest",
    type: :object,
    properties: %{
      clock: %Schema{
        type: :object,
        properties: %{
          time: %Schema{
            type: :string,
            description: "Actual departure in UTC, ISO 8601 or YYYY-MM-DD hh:mm:ss",
            example: "2026-10-04 17:00:00"
          }
        },
        required: [:time]
      }
    },
    required: [:clock]
  })
end
