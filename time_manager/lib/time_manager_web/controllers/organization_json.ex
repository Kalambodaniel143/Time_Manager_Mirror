defmodule TimeManagerWeb.OrganizationJSON do
  alias TimeManager.Organizations.Organization
  alias TimeManagerWeb.UserJSON

  @doc "The result of a lookup: only the id and the name, never the members."
  def lookup(%{organization: %Organization{} = organization}) do
    %{data: %{id: organization.id, name: organization.name}}
  end

  def members(%{users: users}), do: %{data: Enum.map(users, &UserJSON.data(&1, true))}

  def member(%{user: user}), do: %{data: UserJSON.data(user, true)}

  def data(nil), do: nil

  def data(%Organization{} = organization) do
    %{id: organization.id, name: organization.name, created_at: organization.inserted_at}
  end
end
