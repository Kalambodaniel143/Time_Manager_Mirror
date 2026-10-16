defmodule TimeManagerWeb.SessionJSON do
  @moduledoc """
  The Session model of the organizations contract: `role` always equals
  `user.role`, and `user.organization_id` equals `organization.id`
  (`organization` is null for an account without organization).
  """
  alias TimeManager.Accounts.User
  alias TimeManagerWeb.{OrganizationJSON, UserJSON}

  @doc "`user` must have its role and organization loaded."
  def data(%User{} = user) do
    %{
      role: user.role.name,
      user: UserJSON.data(user, true),
      organization: OrganizationJSON.data(user.organization)
    }
  end
end
