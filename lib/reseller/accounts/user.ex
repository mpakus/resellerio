defmodule Reseller.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Reseller.Accounts.Password

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :is_admin, :boolean, default: false

    has_many :api_tokens, Reseller.Accounts.ApiToken
    has_many :products, Reseller.Catalog.Product

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
    |> put_change(:is_admin, false)
    |> put_hashed_password()
  end

  def create_changeset(user, attrs, _metadata) do
    user
    |> cast(attrs, [:email, :password, :confirmed_at, :is_admin])
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_length(:password, min: 12, max: 72)
    |> unsafe_validate_unique(:email, Reseller.Repo)
    |> unique_constraint(:email)
    |> put_hashed_password()
  end

  def update_changeset(user, attrs, _metadata) do
    user
    |> cast(attrs, [:email, :password, :confirmed_at, :is_admin])
    |> update_change(:email, &normalize_email/1)
    |> normalize_password_change()
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_password_if_present()
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

  defp normalize_password_change(changeset) do
    case get_change(changeset, :password) do
      password when is_binary(password) ->
        if byte_size(String.trim(password)) == 0 do
          delete_change(changeset, :password)
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp validate_password_if_present(changeset) do
    case get_change(changeset, :password) do
      password when is_binary(password) ->
        validate_length(changeset, :password, min: 12, max: 72)

      _ ->
        changeset
    end
  end
end
