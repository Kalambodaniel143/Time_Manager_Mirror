defmodule TimeManager.Accounts.PasswordPolicy do
  @moduledoc "Shared password rules for account creation, changes and recovery. Existing logins are unaffected."
  import Ecto.Changeset

  @common ~w(password passwords passw0rd motdepasse azerty qwerty letmein welcome bienvenue admin administrator administrateur gotham gothamcity changeme abcdefgh abcdefghij abcdefghijklmnopqrstuvwxyz)

  def validate(changeset) do
    validate_change(changeset, :password, fn :password, password ->
      # No artificial requirement for punctuation: long passphrases remain valid.
      normalized = password |> String.downcase() |> String.replace(~r/[^\p{L}\p{N}]/u, "")
      base = String.replace(normalized, ~r/\p{N}/u, "")

      if Regex.match?(~r/^\p{N}+$/u, normalized) or
           normalized in @common or base in @common or
           length(Enum.uniq(String.graphemes(normalized))) < 4 or
           Regex.match?(~r/^(.{1,4})\1+$/u, normalized) do
        [
          password:
            "Ce mot de passe est trop facile à deviner. Évitez les suites de chiffres, les répétitions et les mots courants. Choisissez une phrase de plusieurs mots personnels."
        ]
      else
        []
      end
    end)
  end
end
