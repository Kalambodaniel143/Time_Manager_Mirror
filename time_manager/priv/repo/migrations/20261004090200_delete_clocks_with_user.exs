defmodule TimeManager.Repo.Migrations.DeleteClocksWithUser do
  use Ecto.Migration

  # Deleting a user who had clock events used to fail on this foreign key.
  # Clocks now follow their user, like working times already do.
  def change do
    alter table(:clocks) do
      modify :user_id, references(:users, on_delete: :delete_all),
        from: references(:users, on_delete: :nothing)
    end
  end
end
