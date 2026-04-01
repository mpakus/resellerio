defmodule Reseller.Storefronts.Storefront do
  use Ecto.Schema
  import Ecto.Changeset

  alias Reseller.Slugs
  alias Reseller.Storefronts.ThemePresets

  schema "storefronts" do
    field :slug, :string
    field :title, :string
    field :tagline, :string
    field :description, :string
    field :theme_id, :string, default: ThemePresets.default_id()
    field :enabled, :boolean, default: false

    belongs_to :user, Reseller.Accounts.User

    has_many :assets, Reseller.Storefronts.StorefrontAsset, preload_order: [asc: :kind, asc: :id]

    has_many :pages, Reseller.Storefronts.StorefrontPage,
      preload_order: [asc: :position, asc: :id]

    has_many :inquiries, Reseller.Storefronts.StorefrontInquiry,
      preload_order: [desc: :inserted_at, desc: :id]

    timestamps(type: :utc_datetime)
  end

  def create_changeset(storefront, attrs), do: changeset(storefront, attrs)
  def update_changeset(storefront, attrs), do: changeset(storefront, attrs)

  defp changeset(storefront, attrs) do
    storefront
    |> cast(attrs, [:slug, :title, :tagline, :description, :theme_id, :enabled])
    |> update_change(:slug, &normalize_slug/1)
    |> update_change(:title, &normalize_text/1)
    |> update_change(:tagline, &normalize_text/1)
    |> update_change(:description, &normalize_text/1)
    |> put_default_theme_id()
    |> validate_required([:slug, :title, :theme_id])
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> validate_length(:slug, min: 3, max: 80)
    |> validate_length(:title, max: 120)
    |> validate_length(:tagline, max: 180)
    |> validate_length(:description, max: 2000)
    |> validate_theme_id()
    |> assoc_constraint(:user)
    |> unique_constraint(:user_id)
    |> unique_constraint(:slug)
  end

  defp validate_theme_id(changeset) do
    validate_change(changeset, :theme_id, fn :theme_id, theme_id ->
      if ThemePresets.valid_id?(theme_id), do: [], else: [theme_id: "is invalid"]
    end)
  end

  defp put_default_theme_id(changeset) do
    case get_field(changeset, :theme_id) do
      nil -> put_change(changeset, :theme_id, ThemePresets.default_id())
      "" -> put_change(changeset, :theme_id, ThemePresets.default_id())
      _theme_id -> changeset
    end
  end

  defp normalize_slug(value) do
    case Slugs.slugify(value, max_length: 80) do
      "" -> nil
      slug -> slug
    end
  end

  defp normalize_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_text(value), do: value
end
