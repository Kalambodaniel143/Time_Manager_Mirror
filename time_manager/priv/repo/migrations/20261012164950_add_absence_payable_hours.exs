defmodule TimeManager.Repo.Migrations.AddAbsencePayableHours do
  use Ecto.Migration

  def change do
    alter table(:absence_requests) do
      add :payable_hours, :decimal, precision: 12, scale: 4
    end
  end
end
