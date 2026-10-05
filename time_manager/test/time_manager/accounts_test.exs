defmodule TimeManager.AccountsTest do
  use TimeManager.DataCase

  alias TimeManager.Accounts
  alias TimeManager.Accounts.User

  import TimeManager.AccountsFixtures

  @invalid_attrs %{username: nil, email: nil}

  describe "users" do
    test "list_users/0 returns all users" do
      user = user_fixture()
      assert [%User{id: id}] = Accounts.list_users()
      assert id == user.id
    end

    test "get_user!/1 returns the user with given id and role" do
      user = user_fixture()
      assert %User{id: id, role: %{name: "employee"}} = Accounts.get_user!(user.id)
      assert id == user.id
    end

    test "create_user/1 hashes the password and never stores it in clear" do
      attrs = %{username: "alice", email: "Alice@Example.com", password: valid_password()}

      assert {:ok, %User{} = user} = Accounts.create_user(attrs)
      assert user.username == "alice"
      assert user.email == "alice@example.com"
      assert user.role.name == "employee"
      assert user.password == nil
      assert user.password_hash != valid_password()
      assert Bcrypt.verify_pass(valid_password(), user.password_hash)
    end

    test "create_user/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_user(@invalid_attrs)
    end

    test "create_user/1 requires an X@X.X e-mail and an 8-character password" do
      attrs = %{username: "bob", email: "not-an-email", password: "short"}
      assert {:error, changeset} = Accounts.create_user(attrs)
      assert %{email: [_], password: [_]} = errors_on(changeset)
    end

    test "create_user/1 rejects an e-mail already used, whatever its case" do
      user_fixture(email: "taken@example.com")
      attrs = %{username: "x", email: "TAKEN@example.com", password: valid_password()}
      assert {:error, changeset} = Accounts.create_user(attrs)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "create_user/2 rejects an unknown role" do
      attrs = %{username: "x", email: unique_email(), password: valid_password()}
      assert {:error, changeset} = Accounts.create_user(attrs, "superuser")
      assert %{role: [_]} = errors_on(changeset)
    end

    test "update_user/2 changes the profile but never the role" do
      user = user_fixture()
      attrs = %{username: "new name", email: "new@example.com", role_id: -1}

      assert {:ok, %User{} = user} = Accounts.update_user(user, attrs)
      assert user.username == "new name"
      assert user.email == "new@example.com"
      assert user.role.name == "employee"
    end

    test "update_user/2 with invalid data returns error changeset" do
      user = user_fixture()
      assert {:error, %Ecto.Changeset{}} = Accounts.update_user(user, @invalid_attrs)
      assert Accounts.get_user!(user.id).username == user.username
    end

    test "delete_user/1 deletes the user" do
      user = user_fixture()
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end

    test "change_user/1 returns a user changeset" do
      user = user_fixture()
      assert %Ecto.Changeset{} = Accounts.change_user(user)
    end
  end

  describe "authenticate/2" do
    test "accepts the right password, case-insensitively on the e-mail" do
      user = user_fixture(email: "carol@example.com")
      assert {:ok, %User{id: id}} = Accounts.authenticate("CAROL@example.com", valid_password())
      assert id == user.id
    end

    test "gives the same answer for a wrong password and an unknown e-mail" do
      user_fixture(email: "dave@example.com")

      assert {:error, :invalid_credentials} =
               Accounts.authenticate("dave@example.com", "wrong password")

      assert {:error, :invalid_credentials} =
               Accounts.authenticate("nobody@example.com", valid_password())
    end

    test "rejects an account without a password" do
      assert {:error, :invalid_credentials} = Accounts.authenticate(nil, nil)
    end
  end

  describe "passwords" do
    test "change_password/3 requires the current password" do
      user = user_fixture()

      assert {:error, changeset} =
               Accounts.change_password(user, "wrong", %{"password" => "new password!"})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)

      assert {:ok, _user} =
               Accounts.change_password(user, valid_password(), %{"password" => "new password!"})

      assert {:ok, _user} = Accounts.authenticate(user.email, "new password!")
    end

    test "update_account/3 saves nothing when the password change fails" do
      user = user_fixture()

      assert {:error, _changeset} =
               Accounts.update_account(
                 user,
                 %{"username" => "renamed"},
                 {:change, "wrong", "new password!"}
               )

      assert Accounts.get_user!(user.id).username == user.username
    end
  end

  describe "roles" do
    test "list_roles/0 returns the three predefined roles in order" do
      assert ["employee", "manager", "administrator"] ==
               Enum.map(Accounts.list_roles(), & &1.name)
    end

    test "change_role/2 promotes and demotes" do
      user = user_fixture()
      assert {:ok, %User{role: %{name: "manager"}}} = Accounts.change_role(user, "manager")
      assert {:ok, %User{role: %{name: "employee"}}} = Accounts.change_role(user, "employee")
    end

    test "the last administrator can be neither demoted nor deleted" do
      admin = user_fixture(role: "administrator")
      assert {:error, :last_administrator} = Accounts.change_role(admin, "employee")
      assert {:error, :last_administrator} = Accounts.delete_user(admin)

      other = user_fixture(role: "administrator")
      assert {:ok, _admin} = Accounts.change_role(admin, "employee")
      assert {:error, :last_administrator} = Accounts.delete_user(other)
    end
  end
end
