defmodule TimeManager.Repo.Migrations.AddRolesAndPasswords do
  use Ecto.Migration

  # Roles are read-only reference data: the application never creates or edits
  # them. They are inserted here (and again, idempotently, by seeds.exs) so that
  # existing users can be given a role before role_id becomes mandatory.
  def up do
    create table(:roles) do
      add :name, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:roles, [:name])

    execute """
    INSERT INTO roles (name, inserted_at, updated_at)
    VALUES ('employee', now(), now()), ('manager', now(), now()), ('administrator', now(), now())
    """

    alter table(:users) do
      add :password_hash, :string
      add :role_id, references(:roles, on_delete: :restrict)
    end

    execute "UPDATE users SET role_id = (SELECT id FROM roles WHERE name = 'employee')"

    alter table(:users) do
      modify :role_id, :bigint, null: false
    end

    create index(:users, [:role_id])

    # Login is by e-mail, so it must identify one account. Accounts created before
    # authentication may share an address: keep the oldest one as is and suffix
    # the others so the unique index can be built. None of them has a password yet.
    execute """
    UPDATE users SET email = email || '+duplicate-' || id
    WHERE id NOT IN (SELECT min(id) FROM users GROUP BY lower(email))
    """

    # E-mails are now stored in lower case, as the changeset does for new ones.
    execute "UPDATE users SET email = lower(email)"

    create unique_index(:users, ["lower(email)"], name: :users_email_index)
  end

  def down do
    drop index(:users, ["lower(email)"], name: :users_email_index)
    drop index(:users, [:role_id])

    alter table(:users) do
      remove :role_id
      remove :password_hash
    end

    drop table(:roles)
  end
end
