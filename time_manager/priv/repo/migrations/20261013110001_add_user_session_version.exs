defmodule TimeManager.Repo.Migrations.AddUserSessionVersion do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add_if_not_exists :session_version, :integer, null: false, default: 1
    end

    execute("ALTER TABLE users ALTER COLUMN session_version SET DEFAULT 1")
  end

  # La colonne est partagée avec la migration de récupération de mot de passe.
  def down, do: :ok
end
