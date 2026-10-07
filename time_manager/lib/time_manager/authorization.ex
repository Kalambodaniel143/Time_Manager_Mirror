defmodule TimeManager.Authorization do
  @moduledoc """
  Who may do what, and on whose data: the permission matrix of the project.

  A permission always combines a role (what kind of action) and a scope
  (on which data):

    * employee      — self only;
    * manager       — self, plus the members of the teams they manage;
    * administrator — everyone in their own organization.

  Organizations are isolated from each other: no role reaches the data of
  another organization. Users without organization form their own space (see
  `TimeManager.Accounts`).

  The API is the only real barrier: the front-end hides buttons for comfort,
  but every controller asks this module before acting. Identifiers taken from
  the URL are never trusted: they are checked against the session's user.
  """

  alias TimeManager.Accounts
  alias TimeManager.Accounts.User
  alias TimeManager.Teams

  def administrator?(%User{role: %{name: "administrator"}}), do: true
  def administrator?(_user), do: false

  def manager?(%User{role: %{name: "manager"}}), do: true
  def manager?(_user), do: false

  @doc """
  Is `user` an administrator of the organization `organization_id`? Used by the
  organization routes (join requests, members). Users without organization
  administer none.
  """
  def organization_admin?(%User{organization_id: own} = user, organization_id)
      when is_binary(own) do
    administrator?(user) and Ecto.UUID.cast(organization_id) == {:ok, own}
  end

  def organization_admin?(_user, _organization_id), do: false

  @doc """
  Is `user` an administrator of the organization of user `target_id`? This is
  the administrator's scope on users, their hours and their profile.
  """
  def administrator_of?(%User{} = user, target_id) do
    administrator?(user) and Accounts.in_organization?(target_id, user.organization_id)
  end

  @doc "Can `user` administer `team`? An administrator of its organization."
  def administrator_of_team?(%User{} = user, team) do
    administrator?(user) and team.organization_id == user.organization_id
  end

  @doc """
  Can `user` read the profile, clock events, working times and charts of the
  user `target_id`? Self, the managers of the target's teams, the
  administrators of the target's organization.
  """
  def can_view?(%User{id: id}, id), do: true

  def can_view?(%User{} = user, target_id),
    do: administrator_of?(user, target_id) or manages?(user, target_id)

  @doc """
  Can `user` create, correct or delete working times of `target_id`?
  Administrators of the organization always; managers for their team members
  but never for themselves (no one validates their own hours); employees never.
  """
  def can_edit_hours?(%User{} = user, target_id) do
    administrator_of?(user, target_id) or (user.id != target_id and manages?(user, target_id))
  end

  @doc "Clocking in or out is personal: everyone clocks for themselves only."
  def can_clock?(%User{id: id}, id), do: true
  def can_clock?(_user, _target_id), do: false

  @doc "Can `user` edit the profile of `target_id`? Self or an administrator of their organization."
  def can_edit_profile?(%User{id: id}, id), do: true
  def can_edit_profile?(user, target_id), do: administrator_of?(user, target_id)

  @doc """
  Can `user` change the role of `target_id`? An administrator of their
  organization, never on themselves.
  """
  def can_change_role?(%User{id: id}, id), do: false
  def can_change_role?(user, target_id), do: administrator_of?(user, target_id)

  @doc """
  Personal details (gender, birth date and place) are shown to the user
  themselves and to the administrators of their organization only.
  """
  def can_see_personal_details?(%User{id: id}, %User{id: id}), do: true

  def can_see_personal_details?(%User{} = viewer, %User{} = target) do
    administrator?(viewer) and viewer.organization_id == target.organization_id
  end

  @doc """
  The users `user` may search: their organization for an administrator, the
  members of their teams (and themselves) for a manager, and `:forbidden` for
  an employee.
  """
  def user_scope(%User{} = user) do
    cond do
      administrator?(user) -> {:organization, user.organization_id}
      manager?(user) -> [user.id | Teams.managed_member_ids(user.id)]
      true -> :forbidden
    end
  end

  defp manages?(%User{} = user, target_id) do
    manager?(user) and Teams.manages?(user.id, target_id)
  end
end
