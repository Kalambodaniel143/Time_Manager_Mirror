defmodule TimeManager.Email do
  import Swoosh.Email

  def password_recovery(email, code) do
    new()
    |> to(email)
    |> from(Application.fetch_env!(:time_manager, :resend_from_email))
    |> subject("Time Manager — Réinitialiser votre mot de passe / Reset your password")
    |> text_body(
      "Votre code : #{code}. Il expire dans 15 minutes et ne peut être utilisé qu’une fois. Saisissez-le sur la page « Mot de passe oublié ». Si vous n’avez rien demandé, ignorez cet email.\n\nYour code: #{code}. It expires in 15 minutes and can only be used once. Enter it on the ‘Forgot password’ page. If you did not request this, ignore this email."
    )
  end

  def password_changed(email) do
    new()
    |> to(email)
    |> from(Application.fetch_env!(:time_manager, :resend_from_email))
    |> subject("Time Manager — Mot de passe modifié / Password changed")
    |> text_body(
      "Votre mot de passe vient d’être modifié. Toutes vos anciennes sessions ont été fermées. Si vous n’êtes pas à l’origine de cette modification, utilisez « Mot de passe oublié » et contactez votre administrateur. Aucun mot de passe n’est envoyé par email.\n\nYour password has been changed. All previous sessions have been signed out. If you did not request this change, use ‘Forgot password’ and contact your administrator."
    )
  end

  @doc "Builds the one-time email verification message."
  def verification(email, code) do
    new()
    |> to(email)
    |> from(Application.fetch_env!(:time_manager, :resend_from_email))
    |> subject("Votre code de vérification Time Manager")
    |> text_body("Votre code de vérification est #{code}. Il expire dans 10 minutes.")
  end

  @doc "Builds the account credentials message sent after an administrator approves a request."
  def credentials(email, user, password, organization) do
    new()
    |> to(email)
    |> from(Application.fetch_env!(:time_manager, :resend_from_email))
    |> subject("Vos identifiants Time Manager")
    |> text_body("""
    Bonjour #{user.first_name} #{user.last_name},

    Votre demande d'accès à #{organization.name} a été acceptée.

    Nom d'utilisateur : #{user.username}
    Adresse e-mail : #{user.email}
    Mot de passe : #{password}

    Vous pouvez vous connecter depuis l'application Time Manager.
    Pour votre sécurité, changez ce mot de passe après votre première connexion.
    """)
  end
end
