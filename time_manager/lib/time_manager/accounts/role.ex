defmodule TimeManager.Accounts.Role do
  @moduledoc """
  A predefined role. Roles are read-only: they are inserted by the migrations
  and seeds, and the application only reads them.
  """
  use Ecto.Schema

  @names ~w(employee manager administrator)

  schema "roles" do
    field :name, :string
    timestamps(type: :utc_datetime)
  end

  @doc "The role names, from the least to the most privileged."
  def names, do: @names
end
