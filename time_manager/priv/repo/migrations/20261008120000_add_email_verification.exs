defmodule TimeManager.Repo.Migrations.AddEmailVerification do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :email_verified_at, :utc_datetime
    end

    execute "UPDATE users SET email_verified_at = NOW() WHERE email_verified_at IS NULL",
            "UPDATE users SET email_verified_at = NULL"

    create table(:email_verifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :code_hash, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :attempts, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create unique_index(:email_verifications, [:user_id])
  end
end
