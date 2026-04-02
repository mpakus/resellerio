defmodule Reseller.Storefronts.StorefrontAsset do
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(header logo)

  schema "storefront_assets" do
    field :kind, :string
    field :storage_key, :string
    field :content_type, :string
    field :original_filename, :string
    field :width, :integer
    field :height, :integer
    field :byte_size, :integer
    field :checksum, :string

    belongs_to :storefront, Reseller.Storefronts.Storefront

    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds

  def create_changeset(asset, attrs), do: changeset(asset, attrs)
  def update_changeset(asset, attrs), do: changeset(asset, attrs)

  defp changeset(asset, attrs) do
    asset
    |> cast(attrs, [
      :kind,
      :storage_key,
      :content_type,
      :original_filename,
      :width,
      :height,
      :byte_size,
      :checksum
    ])
    |> update_change(:kind, &normalize_text/1)
    |> update_change(:storage_key, &normalize_text/1)
    |> update_change(:content_type, &normalize_text/1)
    |> update_change(:original_filename, &normalize_text/1)
    |> update_change(:checksum, &normalize_text/1)
    |> validate_required([:kind, :storage_key, :content_type, :original_filename])
    |> validate_inclusion(:kind, @kinds)
    |> validate_length(:storage_key, max: 500)
    |> validate_length(:content_type, max: 120)
    |> validate_format(:content_type, ~r/^image\//, message: "must be an image content type")
    |> validate_length(:original_filename, max: 255)
    |> validate_length(:checksum, max: 128)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:byte_size, greater_than: 0)
    |> assoc_constraint(:storefront)
    |> unique_constraint(:kind, name: :storefront_assets_storefront_id_kind_index)
  end

  defp normalize_text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_text(value), do: value
end
