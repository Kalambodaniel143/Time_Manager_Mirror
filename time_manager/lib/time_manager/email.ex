defmodule TimeManager.Email do
  import Swoosh.Email

  @doc "Builds the one-time email verification message."
  def verification(email, code) do
    new()
    |> to(email)
    |> from(Application.fetch_env!(:time_manager, :resend_from_email))
    |> subject("Votre code de vérification Time Manager")
    |> text_body("Votre code de vérification est #{code}. Il expire dans 10 minutes.")
  end
end
