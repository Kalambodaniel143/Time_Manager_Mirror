defmodule TimeManager.Accounts.Profile do
  @moduledoc """
  Validation rules of the personal fields, shared by users and join requests so
  that a profile accepted in a request is still valid when its account is
  created.

    * identity: `first_name`, `last_name`, `email` (always required);
    * personal details: `gender`, `birth_date`, `birth_place` (required to join
      an organization, not to create one).
  """
  import Ecto.Changeset

  @genders ~w(female male non_binary unspecified)
  # The subject asks for X@X.X: something, an @, something, a dot, something.
  @email_format ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/
  @oldest_birth_date ~D[1900-01-01]

  def genders, do: @genders
  def identity_fields, do: [:first_name, :last_name, :email]
  def personal_fields, do: [:gender, :birth_date, :birth_place]

  def validate_identity(changeset) do
    changeset
    |> trim([:first_name, :last_name])
    |> validate_required([:first_name, :last_name, :email])
    |> validate_length(:first_name, max: 100)
    |> validate_length(:last_name, max: 100)
    |> validate_names()
    |> validate_email()
  end

  def validate_names(changeset) do
    Enum.reduce([:first_name, :last_name], changeset, fn field, acc ->
      validate_format(acc, field, ~r/^[\p{L}\p{M} '\x{2019}-]+$/u,
        message:
          "Utilisez des lettres, des espaces, des apostrophes ou des traits d’union, sans chiffres."
      )
    end)
  end

  @doc "Trims and lower-cases the e-mail, then checks its format and length."
  def validate_email(changeset) do
    changeset
    |> update_change(:email, &(&1 |> String.trim() |> String.downcase()))
    |> validate_format(:email, @email_format, message: "must look like name@domain.tld")
    |> validate_length(:email, max: 254)
  end

  def validate_personal_details(changeset) do
    changeset
    |> trim([:birth_place])
    |> validate_required(personal_fields())
    |> validate_inclusion(:gender, @genders)
    |> validate_length(:birth_place, max: 100)
    |> validate_birth_date()
  end

  defp validate_birth_date(changeset) do
    validate_change(changeset, :birth_date, fn :birth_date, date ->
      today = Date.utc_today()
      eighteenth_birthday = Date.shift(date, year: 18)

      cond do
        Date.compare(date, @oldest_birth_date) == :lt or Date.compare(date, today) == :gt ->
          [birth_date: "Saisissez une date de naissance valide, entre 1900 et aujourd’hui."]

        Date.compare(eighteenth_birthday, today) == :gt ->
          [birth_date: "Vous devez avoir au moins 18 ans pour rejoindre l’organisation."]

        true ->
          []
      end
    end)
  end

  defp trim(changeset, fields) do
    Enum.reduce(fields, changeset, &update_change(&2, &1, fn value -> String.trim(value) end))
  end
end
