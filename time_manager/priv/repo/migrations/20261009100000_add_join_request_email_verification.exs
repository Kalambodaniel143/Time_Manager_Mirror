defmodule TimeManager.Repo.Migrations.AddJoinRequestEmailVerification do
  use Ecto.Migration

  def change do
    alter table(:email_verifications) do
      modify :user_id, :bigint, null: true
      add :join_request_id, references(:join_requests, type: :binary_id, on_delete: :delete_all)
    end

    create unique_index(:email_verifications, [:join_request_id])

    alter table(:join_requests) do
      add :email_verified_at, :utc_datetime
    end
  end
end
