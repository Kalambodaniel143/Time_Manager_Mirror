defmodule TimeManager.Repo.Migrations.AllowJoinRequestVerificationOwner do
  use Ecto.Migration

  def up do
    # La contrainte existante impose exactement un propriétaire, sans effacer de données.
    execute "ALTER TABLE email_verifications ALTER COLUMN user_id DROP NOT NULL"

    execute "ALTER TABLE email_verifications VALIDATE CONSTRAINT email_verifications_one_verification_owner"
  end

  def down do
    # PostgreSQL refuse le retour arrière si des demandes sans compte existent.
    execute "ALTER TABLE email_verifications ALTER COLUMN user_id SET NOT NULL"
  end
end
