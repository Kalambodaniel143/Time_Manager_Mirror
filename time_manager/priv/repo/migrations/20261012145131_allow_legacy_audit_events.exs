defmodule TimeManager.Repo.Migrations.AllowLegacyAuditEvents do
  use Ecto.Migration

  def change do
    alter table(:workforce_events) do
      modify :organization_id, :uuid, null: true
    end
  end
end
