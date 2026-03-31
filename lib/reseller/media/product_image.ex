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
    field :scene_key, :string
    field :variant_index, :integer
    field :source_image_ids, {:array, :integer}, default: []
    field :seller_approved, :boolean, default: false
    field :approved_at, :utc_datetime

    belongs_to :product, Reseller.Catalog.Product
    belongs_to :lifestyle_generation_run, Reseller.AI.ProductLifestyleGenerationRun

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
      :original_filename,
      :scene_key,
      :variant_index,
      :source_image_ids,
      :seller_approved,
      :approved_at,
      :lifestyle_generation_run_id
    ])
    |> validate_required([:kind, :position, :storage_key, :content_type, :processing_status])
    |> validate_inclusion(
      :kind,
      ~w(
        original
        normalized
        white_background
        object_crop
        thumbnail
        background_removed
        background_replaced
        lifestyle_generated
      )
    )
    |> validate_inclusion(:processing_status, ~w(pending_upload uploaded processing ready failed))
    |> validate_number(:position, greater_than: 0)
    |> validate_number(:byte_size, greater_than: 0)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:variant_index, greater_than: 0)
    |> validate_length(:storage_key, max: 512)
    |> validate_length(:scene_key, max: 120)
    |> validate_format(:content_type, ~r/^image\//, message: "must be an image content type")
    |> validate_lifestyle_generated_metadata()
    |> unique_constraint(:storage_key)
    |> unique_constraint([:product_id, :kind, :position])
    |> unique_constraint([:lifestyle_generation_run_id, :scene_key, :variant_index],
      name: :product_images_lifestyle_generation_variant_index
    )
  end

  defp validate_lifestyle_generated_metadata(changeset) do
    if get_field(changeset, :kind) == "lifestyle_generated" do
      changeset
      |> validate_required([:lifestyle_generation_run_id, :scene_key, :variant_index])
      |> validate_length(:source_image_ids, min: 1, max: 3)
    else
      changeset
    end
  end
end
