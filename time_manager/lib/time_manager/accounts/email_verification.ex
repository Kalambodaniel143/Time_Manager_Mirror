defmodule TimeManager.Accounts.EmailVerification do
  use Ecto.Schema

  schema "email_verifications" do
    field :code_hash, :string
    field :expires_at, :utc_datetime
    field :attempts, :integer, default: 0
    belongs_to :user, TimeManager.Accounts.User
    timestamps(type: :utc_datetime)
  end
end
