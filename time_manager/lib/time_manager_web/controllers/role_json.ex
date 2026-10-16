defmodule TimeManagerWeb.RoleJSON do
  def index(%{roles: roles}), do: %{data: Enum.map(roles, &%{id: &1.id, name: &1.name})}
end
