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

  def credentials(email, user, password, organization) do
    new()
    |> to(email)
    |> from(Application.fetch_env!(:time_manager, :resend_from_email))
    |> subject("Votre compte Time Manager est prêt")
    |> text_body("""
    Votre demande a été acceptée par l'administrateur.

    Organisation : #{organization.name}
    Nom d'utilisateur : #{user.username}
    Adresse e-mail : #{user.email}
    Mot de passe : #{password}

    Vous pouvez maintenant vous connecter à Time Manager.
    """)
  end
end
