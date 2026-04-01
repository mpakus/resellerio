defmodule Reseller.Storefronts.StorefrontPage do
  use Ecto.Schema
  import Ecto.Changeset

  alias Reseller.Slugs

  schema "storefront_pages" do
    field :title, :string
    field :slug, :string
    field :menu_label, :string
    field :body, :string
    field :position, :integer, default: 1
    field :published, :boolean, default: false

    belongs_to :storefront, Reseller.Storefronts.Storefront

    timestamps(type: :utc_datetime)
  end

  def create_changeset(page, attrs), do: changeset(page, attrs)
  def update_changeset(page, attrs), do: changeset(page, attrs)

  defp changeset(page, attrs) do
    page
    |> cast(attrs, [:title, :slug, :menu_label, :body, :position, :published])
    |> update_change(:title, &normalize_text/1)
    |> update_change(:slug, &normalize_slug/1)
    |> update_change(:menu_label, &normalize_text/1)
    |> update_change(:body, &normalize_body/1)
    |> put_default_slug()
    |> put_default_menu_label()
    |> validate_required([:title, :slug, :menu_label, :body, :position])
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> validate_length(:title, max: 120)
    |> validate_length(:slug, min: 2, max: 80)
    |> validate_length(:menu_label, max: 40)
    |> validate_length(:body, max: 10_000)
    |> validate_number(:position, greater_than: 0)
    |> assoc_constraint(:storefront)
    |> unique_constraint(:slug, name: :storefront_pages_storefront_id_slug_index)
  end

  defp put_default_slug(changeset) do
    title = get_field(changeset, :title)

    case {changeset.data.id, fetch_change(changeset, :slug), title} do
      {nil, :error, title} when is_binary(title) and title != "" ->
        put_change(changeset, :slug, Slugs.slugify(title, max_length: 80))

      {nil, {:ok, nil}, title} when is_binary(title) and title != "" ->
        put_change(changeset, :slug, Slugs.slugify(title, max_length: 80))

      _other ->
        changeset
    end
  end

  defp put_default_menu_label(changeset) do
    case {get_field(changeset, :menu_label), get_field(changeset, :title)} do
      {nil, title} when is_binary(title) and title != "" ->
        put_change(changeset, :menu_label, title)

      {"", title} when is_binary(title) and title != "" ->
        put_change(changeset, :menu_label, title)

      _other ->
        changeset
    end
  end

  defp normalize_slug(value) do
    case Slugs.slugify(value, max_length: 80) do
      "" -> nil
      slug -> slug
    end
  end

  defp normalize_body(value) when is_binary(value) do
    case value |> String.trim() do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_body(value), do: value

  defp normalize_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_text(value), do: value
end
