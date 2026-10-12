defmodule TimeManager.Repo.Migrations.AddJoinRequestEmailVerification do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE join_requests ADD COLUMN IF NOT EXISTS email_verified_at timestamptz"

    execute "ALTER TABLE email_verifications ADD COLUMN IF NOT EXISTS join_request_id uuid REFERENCES join_requests(id) ON DELETE CASCADE"

    execute "CREATE UNIQUE INDEX IF NOT EXISTS email_verifications_join_request_id_index ON email_verifications (join_request_id)"

    execute "CREATE INDEX IF NOT EXISTS join_requests_organization_id_email_verified_at_index ON join_requests (organization_id, email_verified_at)"

    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'email_verifications_one_verification_owner'
      ) THEN
        ALTER TABLE email_verifications
        ADD CONSTRAINT email_verifications_one_verification_owner
        CHECK ((user_id IS NOT NULL)::integer + (join_request_id IS NOT NULL)::integer = 1);
      END IF;
    END
    $$;
    """
  end

  def down do
    drop constraint(:email_verifications, :email_verifications_one_verification_owner)
    drop index(:join_requests, [:organization_id, :email_verified_at])
    drop index(:email_verifications, [:join_request_id])
    alter table(:email_verifications), do: remove(:join_request_id)
    alter table(:join_requests), do: remove(:email_verified_at)
  end
end
