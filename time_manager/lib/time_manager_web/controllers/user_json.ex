defmodule TimeManagerWeb.UserJSON do
  alias TimeManager.Accounts.User
  alias TimeManager.Authorization

  @doc """
  Renders a list of users.
  """
  def index(%{users: users} = assigns) do
    %{data: for(user <- users, do: data(user, personal_details?(assigns, user)))}
  end

  @doc """
  Renders a single user.
  """
  def show(%{user: user} = assigns) do
    %{data: data(user, personal_details?(assigns, user))}
  end

  @doc """
  The public fields of a user. The password hash is never rendered. Gender,
  birth date and birth place are only added with `personal_details` (the user
  themselves or an administrator of their organization).
  """
  def data(%User{} = user, personal_details \\ false) do
    public = %{
      id: user.id,
      username: user.username,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      organization_id: user.organization_id,
      role: user.role.name,
      inserted_at: user.inserted_at,
      created_at: user.inserted_at
    }

    if personal_details do
      Map.merge(public, Map.take(user, [:gender, :birth_date, :birth_place]))
    else
      public
    end
  end

  defp personal_details?(%{viewer: viewer}, user),
    do: Authorization.can_see_personal_details?(viewer, user)

  defp personal_details?(_assigns, _user), do: false
end
