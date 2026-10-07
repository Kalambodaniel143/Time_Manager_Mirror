defmodule TimeManagerWeb.Schemas.Profile do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Profile",
    description:
      "Personal fields. gender, birth_date and birth_place are required to join an " <>
        "organization, not to create one.",
    type: :object,
    properties: %{
      first_name: %Schema{type: :string, maxLength: 100, example: "Sara"},
      last_name: %Schema{type: :string, maxLength: 100, example: "Martin"},
      email: %Schema{type: :string, format: :email, maxLength: 254, example: "sara@example.com"},
      gender: %Schema{
        type: :string,
        enum: ["female", "male", "non_binary", "unspecified"],
        example: "female"
      },
      birth_date: %Schema{type: :string, format: :date, example: "1999-03-12"},
      birth_place: %Schema{type: :string, maxLength: 100, example: "Paris"}
    },
    required: [:first_name, :last_name, :email]
  })
end
