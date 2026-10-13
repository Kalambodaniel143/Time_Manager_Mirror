defmodule TimeManager.Repo.Migrations.AddPasswordRecoveryAndSessionVersion do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :session_version, :integer, null: false, default: 0
    end

    create table(:password_recoveries, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), primary_key: true
      add :code_hash, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :attempts, :integer, null: false, default: 0
    end
  end
end
