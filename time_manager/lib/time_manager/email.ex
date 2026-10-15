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

  @doc "Confirme l'admission sans envoyer de mot de passe par courriel."
  def credentials(email, user, organization) do
    new()
    |> to(email)
    |> from(Application.fetch_env!(:time_manager, :resend_from_email))
    |> subject("Vos identifiants Time Manager")
    |> text_body("""
    Bonjour #{user.first_name} #{user.last_name},

    Votre demande d'accès à #{organization.name} a été acceptée.

    Nom d'utilisateur : #{user.username}
    Adresse e-mail : #{user.email}
    Votre administrateur vous communiquera le mot de passe initial par un canal sécurisé séparé.
    Vous pourrez ensuite vous connecter depuis l'application Time Manager.
    Pour votre sécurité, changez ce mot de passe après votre première connexion.
    """)
  end
end
