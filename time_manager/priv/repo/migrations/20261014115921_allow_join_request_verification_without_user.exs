defmodule TimeManager.Repo.Migrations.AllowJoinRequestVerificationWithoutUser do
  use Ecto.Migration

  def up do
    # Exactly one owner is still required by email_verifications_one_verification_owner.
    execute "ALTER TABLE email_verifications ALTER COLUMN user_id DROP NOT NULL"
  end

  def down do
    # Restore NOT NULL only after dropping join-request verification support;
    # keeping nullable here preserves valid pending join requests on rollback.
    :ok
  end
end
