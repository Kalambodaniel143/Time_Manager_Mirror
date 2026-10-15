defmodule TimeManager.InputPolicyTest do
  use TimeManager.DataCase, async: true
  import TimeManager.AccountsFixtures
  alias TimeManager.{Accounts, Teams, Workforce}

  test "names accept accented and compound names but refuse digits on creation and edit" do
    admin = organization_admin_fixture()

    for key <- ["first_name", "last_name"] do
      assert {:error, changeset} =
               TimeManager.Organizations.submit_join_request(
                 admin.organization_id,
                 join_profile(%{key => "Jean2"})
               )

      assert Map.has_key?(errors_on(changeset), String.to_existing_atom(key))
    end

    user = user_fixture()
    assert {:error, _} = Accounts.update_user(user, %{first_name: "A１２"})

    assert {:ok, _} =
             Accounts.update_user(user, %{first_name: "Éléonore", last_name: "D’Angelo-Santos"})
  end

  test "admission requires the eighteenth birthday to have occurred" do
    admin = organization_admin_fixture()
    adult = Date.shift(Date.utc_today(), year: -18)

    assert {:ok, _, _} =
             TimeManager.Organizations.submit_join_request(
               admin.organization_id,
               join_profile(%{"birth_date" => Date.to_iso8601(adult)})
             )

    assert {:error, changeset} =
             TimeManager.Organizations.submit_join_request(
               admin.organization_id,
               join_profile(%{"birth_date" => Date.to_iso8601(Date.add(adult, 1))})
             )

    assert errors_on(changeset).birth_date != []
  end

  test "simple passwords are rejected on creation and reset while passphrases work" do
    user = user_fixture()

    for password <- [
          "123456789",
          "987654321",
          "Password2026!",
          "azerty123",
          "aaaaaaaa",
          "abcdabcd"
        ] do
      assert {:error, changeset} = Accounts.reset_password(user, %{password: password})
      assert errors_on(changeset).password != []
    end

    assert {:ok, _} = Accounts.reset_password(user, %{password: "my personal secret phrase"})
  end

  test "a manager cannot also be a member, including after a manager reassignment" do
    manager = user_fixture(role: "manager")
    replacement = user_fixture(role: "manager")
    team = team_fixture(manager_id: manager.id, members: [replacement])
    assert {:error, {:unprocessable_entity, _}} = Teams.add_member(team, manager)
    assert {:ok, updated} = Teams.update_team(team, %{manager_id: replacement.id})
    assert updated.members == []
    # A stale team loaded before reassignment must still use the current manager.
    assert {:error, {:unprocessable_entity, _}} = Teams.add_member(team, replacement)
  end

  test "notification filters, count and read ownership use the logged-in account" do
    user = user_fixture()
    other = user_fixture()
    mine = Workforce.notify(user.id, "Correction acceptée", "Vos horaires ont été mis à jour.")
    theirs = Workforce.notify(other.id, "Privé", "Privé")
    assert Workforce.unread_notification_count(user) == 1
    assert [item] = Workforce.notifications(user, "unread")
    assert item.id == mine.id
    assert {:error, :forbidden} = Workforce.read_notification(user, theirs.id)
    assert {:ok, _} = Workforce.read_notification(user, mine.id)
    assert Workforce.notifications(user, "unread") == []
    assert length(Workforce.notifications(user, "read")) == 1
    assert Workforce.unread_notification_count(user) == 0
  end
end
