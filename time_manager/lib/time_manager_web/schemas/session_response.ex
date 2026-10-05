defmodule TimeManagerWeb.Schemas.SessionResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  alias TimeManagerWeb.Schemas.User

  OpenApiSpex.schema(%{
    title: "SessionResponse",
    description:
      "Returned at login. The JWT itself is in the HttpOnly `jwt` cookie; send csrf_token " <>
        "back in the X-CSRF-Token header of every request.",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          csrf_token: %Schema{type: :string, example: "k3J9..."},
          user: User
        },
        required: [:csrf_token, :user]
      }
    },
    required: [:data]
  })
end
