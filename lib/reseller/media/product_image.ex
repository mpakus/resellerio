defmodule Reseller.Media.ProductImage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "product_images" do
    field :kind, :string, default: "original"
    field :position, :integer
    field :storage_key, :string
    field :content_type, :string
    field :width, :integer
    field :height, :integer
    field :byte_size, :integer
    field :checksum, :string
    field :background_style, :string
    field :processing_status, :string, default: "pending_upload"
    field :original_filename, :string

    belongs_to :product, Reseller.Catalog.Product

    timestamps(type: :utc_datetime)
  end

  def create_changeset(product_image, attrs) do
    product_image
    |> cast(attrs, [
      :kind,
      :position,
      :storage_key,
      :content_type,
      :width,
      :height,
      :byte_size,
      :checksum,
      :background_style,
      :processing_status,
      :original_filename
    ])
    |> validate_required([:kind, :position, :storage_key, :content_type, :processing_status])
    |> validate_inclusion(
      :kind,
      ~w(original normalized white_background object_crop thumbnail background_removed background_replaced)
    )
    |> validate_inclusion(:processing_status, ~w(pending_upload uploaded processing ready failed))
    |> validate_number(:position, greater_than: 0)
    |> validate_number(:byte_size, greater_than: 0)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_length(:storage_key, max: 512)
    |> validate_format(:content_type, ~r/^image\//, message: "must be an image content type")
    |> unique_constraint(:storage_key)
    |> unique_constraint([:product_id, :position])
  end
end
