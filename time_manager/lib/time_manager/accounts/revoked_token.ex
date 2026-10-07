defmodule TimeManager.Accounts.RevokedToken do
  @moduledoc """
  A session JWT ended by a logout, identified by its `jti` claim. It is kept
  until its own expiry date: after that, the signature check rejects it anyway.
  """
  use Ecto.Schema

  @primary_key {:jti, :string, autogenerate: false}

  schema "revoked_tokens" do
    field :expires_at, :utc_datetime
  end
end
