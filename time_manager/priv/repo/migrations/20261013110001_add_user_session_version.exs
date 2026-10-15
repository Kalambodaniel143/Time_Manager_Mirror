defmodule TimeManager.Repo.Migrations.AddUserSessionVersion do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :session_version, :integer, null: false, default: 1
    end
  end
end
