defmodule TimeManager.Repo.Migrations.AddWorkforceWorkflows do
  use Ecto.Migration

  def change do
    create table(:workforce_settings) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :delete_all),
        null: false

      add :rules, :map, default: %{}, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:workforce_settings, [:organization_id])

    create table(:team_permissions) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :validate, :boolean, default: true, null: false
      add :correct, :boolean, default: true, null: false
      add :publish, :boolean, default: false, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:team_permissions, [:team_id])

    create table(:account_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :settings, :map, default: %{}, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:account_preferences, [:user_id])

    create table(:weekly_sheets) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :week, :date, null: false
      add :note, :text, default: "", null: false
      add :status, :string, default: "open", null: false
      add :reviewer_id, references(:users, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime
      add :reason, :text, default: "", null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:weekly_sheets, [:user_id, :week])

    create table(:correction_requests) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :period_id, references(:workingtime, on_delete: :nilify_all)
      add :before_start, :utc_datetime, null: false
      add :before_end, :utc_datetime, null: false
      add :start, :utc_datetime, null: false
      add :end, :utc_datetime, null: false
      add :reason, :text, null: false
      add :status, :string, default: "pending", null: false
      add :reviewer_id, references(:users, on_delete: :nilify_all)
      add :review_reason, :text, default: "", null: false
      add :reviewed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:correction_requests, [:user_id])

    create table(:workforce_plans) do
      add :team_id, references(:teams, on_delete: :delete_all), null: false
      add :start, :date, null: false
      add :days, :integer, default: 14, null: false
      add :revision, :integer, default: 1, null: false
      add :published_revision, :integer
      add :published_at, :utc_datetime
      add :snapshot, :map, default: %{}, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:workforce_plans, [:team_id, :start])

    create table(:planned_shifts) do
      add :plan_id, references(:workforce_plans, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :start, :utc_datetime, null: false
      add :end, :utc_datetime, null: false
      add :kind, :string, default: "day", null: false
      add :place, :string, default: "", null: false
      timestamps(type: :utc_datetime)
    end

    create index(:planned_shifts, [:user_id])

    create table(:shift_swaps) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :target_user_id, references(:users, on_delete: :delete_all), null: false
      add :shift_id, references(:planned_shifts, on_delete: :nilify_all)
      add :target_shift_id, references(:planned_shifts, on_delete: :nilify_all)
      add :proposal, :map, null: false
      add :reason, :text, null: false
      add :status, :string, default: "pending", null: false
      add :reviewer_id, references(:users, on_delete: :nilify_all)
      add :review_reason, :text, default: "", null: false
      add :reviewed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:shift_swaps, [:user_id])

    create table(:absence_requests) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :start, :utc_datetime, null: false
      add :end, :utc_datetime, null: false
      add :kind, :string, null: false
      add :reason, :text, default: "", null: false
      add :status, :string, default: "pending", null: false
      add :reviewer_id, references(:users, on_delete: :nilify_all)
      add :review_reason, :text, default: "", null: false
      add :reviewed_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:absence_requests, [:user_id])

    create table(:payroll_profiles) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :hourly_rate, :decimal, precision: 12, scale: 2
      add :currency, :string, default: "EUR", null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:payroll_profiles, [:user_id])

    create table(:workforce_events) do
      add :organization_id, references(:organizations, type: :uuid, on_delete: :delete_all),
        null: false

      add :actor_id, references(:users, on_delete: :nilify_all)
      add :action, :string, null: false
      add :details, :map, default: %{}, null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create table(:workforce_notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :body, :text, null: false
      add :read_at, :utc_datetime
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:workforce_notifications, [:user_id])

    create unique_index(:correction_requests, [:period_id],
             where: "status = 'pending'",
             name: :one_pending_correction
           )

    create constraint(:weekly_sheets, :valid_sheet_status,
             check: "status IN ('open','validated','closed')"
           )

    create constraint(:planned_shifts, :positive_shift, check: "\"end\" > start")

    alter table(:workingtime) do
      add :kind, :string, default: "work", null: false
    end
  end
end
