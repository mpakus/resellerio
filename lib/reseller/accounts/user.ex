defmodule Reseller.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Reseller.Accounts.Password
  alias Reseller.Marketplaces

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :is_admin, :boolean, default: false
    field :selected_marketplaces, {:array, :string}, default: []

    field :plan, :string, default: "free"
    field :plan_status, :string, default: "free"
    field :plan_period, :string
    field :plan_expires_at, :utc_datetime
    field :trial_ends_at, :utc_datetime
    field :ls_subscription_id, :string
    field :ls_customer_id, :string
    field :ls_variant_id, :string
    field :addon_credits, :map, default: %{}
    field :subscription_reminder_7d_sent_at, :utc_datetime
    field :subscription_reminder_2d_sent_at, :utc_datetime

    has_many :api_tokens, Reseller.Accounts.ApiToken
    has_many :products, Reseller.Catalog.Product
    has_one :storefront, Reseller.Storefronts.Storefront

    timestamps(type: :utc_datetime)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :selected_marketplaces])
    |> update_change(:email, &normalize_email/1)
    |> normalize_selected_marketplaces()
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_length(:password, min: 12, max: 72)
    |> validate_selected_marketplaces()
    |> unsafe_validate_unique(:email, Reseller.Repo)
    |> unique_constraint(:email)
    |> put_change(:is_admin, false)
    |> put_default_selected_marketplaces()
    |> put_hashed_password()
  end

  def create_changeset(user, attrs, _metadata) do
    user
    |> cast(attrs, [:email, :password, :confirmed_at, :is_admin, :selected_marketplaces])
    |> update_change(:email, &normalize_email/1)
    |> normalize_selected_marketplaces()
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_length(:password, min: 12, max: 72)
    |> validate_selected_marketplaces()
    |> unsafe_validate_unique(:email, Reseller.Repo)
    |> unique_constraint(:email)
    |> put_default_selected_marketplaces()
    |> put_hashed_password()
  end

  def update_changeset(user, attrs, _metadata) do
    user
    |> cast(attrs, [:email, :password, :confirmed_at, :is_admin, :selected_marketplaces])
    |> update_change(:email, &normalize_email/1)
    |> normalize_password_change()
    |> normalize_selected_marketplaces()
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> validate_password_if_present()
    |> validate_selected_marketplaces()
    |> unsafe_validate_unique(:email, Reseller.Repo)
    |> unique_constraint(:email)
    |> put_default_selected_marketplaces()
    |> put_hashed_password()
  end

  def marketplace_settings_changeset(user, attrs) do
    user
    |> cast(attrs, [:selected_marketplaces])
    |> normalize_selected_marketplaces()
    |> validate_selected_marketplaces()
  end

  @subscription_fields ~w(
    plan plan_status plan_period plan_expires_at trial_ends_at
    ls_subscription_id ls_customer_id ls_variant_id addon_credits
    subscription_reminder_7d_sent_at subscription_reminder_2d_sent_at
  )a

  def subscription_changeset(user, attrs) do
    user
    |> cast(attrs, @subscription_fields)
    |> validate_inclusion(:plan, ~w(free starter growth pro))
    |> validate_inclusion(:plan_status, ~w(free trialing active canceling past_due expired))
    |> validate_inclusion(:plan_period, ~w(monthly annual), allow_nil: true)
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

  defp normalize_selected_marketplaces(changeset) do
    update_change(changeset, :selected_marketplaces, fn marketplaces ->
      marketplaces
      |> List.wrap()
      |> Enum.map(fn
        marketplace when is_binary(marketplace) -> String.trim(marketplace)
        marketplace -> marketplace |> to_string() |> String.trim()
      end)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
    end)
  end

  defp validate_selected_marketplaces(changeset) do
    allowed_marketplaces = Marketplaces.supported_marketplaces()

    changeset
    |> validate_change(:selected_marketplaces, fn :selected_marketplaces, marketplaces ->
      case Marketplaces.invalid_marketplaces(marketplaces, allowed_marketplaces) do
        [] ->
          []

        invalid_marketplaces ->
          [
            selected_marketplaces:
              "contains unsupported marketplaces: #{Enum.join(invalid_marketplaces, ", ")}"
          ]
      end
    end)
    |> update_change(
      :selected_marketplaces,
      &Marketplaces.normalize_marketplaces(&1, allowed_marketplaces)
    )
  end

  defp put_default_selected_marketplaces(changeset) do
    case fetch_change(changeset, :selected_marketplaces) do
      {:ok, _marketplaces} ->
        changeset

      :error ->
        if is_nil(changeset.data.id) and (changeset.data.selected_marketplaces || []) == [] do
          put_change(changeset, :selected_marketplaces, Marketplaces.default_marketplaces())
        else
          changeset
        end
    end
  end
end
