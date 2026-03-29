defmodule Reseller.Media.UploadSpec do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :filename, :string
    field :content_type, :string
    field :byte_size, :integer
    field :position, :integer
    field :checksum, :string
    field :width, :integer
    field :height, :integer
  end

  def changeset(upload_spec, attrs) do
    upload_spec
    |> cast(attrs, [:filename, :content_type, :byte_size, :position, :checksum, :width, :height])
    |> validate_required([:filename, :content_type, :byte_size])
    |> validate_number(:byte_size, greater_than: 0, less_than_or_equal_to: 25_000_000)
    |> validate_number(:position, greater_than: 0)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_length(:filename, min: 1, max: 255)
    |> validate_format(:content_type, ~r/^image\//, message: "must be an image content type")
  end
end
