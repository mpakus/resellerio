defmodule Reseller.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Reseller.Accounts.Password

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime

    has_many :api_tokens, Reseller.Accounts.ApiToken

    timestamps(type: :utc_datetime)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_length(:password, min: 12, max: 72)
    |> unsafe_validate_unique(:email, Reseller.Repo)
    |> unique_constraint(:email)
    |> put_hashed_password()
  end

  defp put_hashed_password(changeset) do
    case get_change(changeset, :password) do
      password when is_binary(password) ->
        changeset
        |> validate_confirmation(:password, required: false)
        |> put_change(:hashed_password, Password.hash_password(password))

      _ ->
        changeset
    end
  end

  defp normalize_email(email) when is_binary(email) do
    email
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_email(email), do: email
end
