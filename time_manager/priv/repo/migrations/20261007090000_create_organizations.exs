defmodule TimeManager.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  # Organizations, join requests and revoked sessions (see
  # docs/CONTRAT_BACKEND_ORGANISATIONS.md). Existing users and teams keep a NULL
  # organization: together they form their own space, isolated from every
  # organization, so nothing created before this migration changes owner.
  def change do
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, size: 100, null: false
      # Lower case, no accents, single spaces: "Atelier  Gotham" and
      # "atelier gotham" are the same organization.
      add :normalized_name, :string, size: 100, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organizations, [:normalized_name])

    alter table(:users) do
      add :first_name, :string, size: 100
      add :last_name, :string, size: 100
      add :gender, :string
      add :birth_date, :date
      add :birth_place, :string, size: 100
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :restrict)
    end

    create index(:users, [:organization_id])

    # A team belongs to one organization; its name is unique inside it only.
    # NULLS NOT DISTINCT keeps the old global uniqueness for teams without one.
    alter table(:teams) do
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :restrict)
    end

    drop unique_index(:teams, [:name])
    create unique_index(:teams, [:organization_id, :name], nulls_distinct: false)

    create table(:join_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :organization_id,
          references(:organizations, type: :binary_id, on_delete: :delete_all),
          null: false

      add :first_name, :string, size: 100, null: false
      add :last_name, :string, size: 100, null: false
      add :email, :string, size: 254, null: false
      add :gender, :string, null: false
      add :birth_date, :date, null: false
      add :birth_place, :string, size: 100, null: false
      add :status, :string, null: false, default: "pending"
      # SHA-256 of the private tracking reference: the reference itself is
      # never stored, so a database leak does not reveal it.
      add :reference_hash, :binary, null: false
      add :rejection_reason, :string, size: 500
      add :reviewed_at, :utc_datetime
      add :reviewed_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:join_requests, [:reference_hash])
    create index(:join_requests, [:organization_id])

    # One pending request per e-mail and organization, even under concurrency.
    create unique_index(:join_requests, [:organization_id, :email],
             where: "status = 'pending'",
             name: :join_requests_pending_email_index
           )

    create constraint(:join_requests, :join_requests_status,
             check: "status IN ('pending', 'approved', 'rejected')"
           )

    # Session JWTs revoked by a logout, kept until they would have expired.
    create table(:revoked_tokens, primary_key: false) do
      add :jti, :string, primary_key: true
      add :expires_at, :utc_datetime, null: false
    end

    create index(:revoked_tokens, [:expires_at])
  end
end
