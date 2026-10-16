defmodule TimeManagerWeb.Schemas.AccountDeletionRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AccountDeletionRequest",
    description:
      "To delete your own account, send your current password. An administrator deleting " <>
        "another user's account does not need that user's password.",
    type: :object,
    properties: %{
      current_password: %Schema{type: :string, format: :password, writeOnly: true}
    }
  })
end
