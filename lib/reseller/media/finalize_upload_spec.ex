defmodule Reseller.Media.FinalizeUploadSpec do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field :id, :integer
    field :byte_size, :integer
    field :checksum, :string
    field :width, :integer
    field :height, :integer
  end

  def changeset(upload_spec, attrs) do
    upload_spec
    |> cast(attrs, [:id, :byte_size, :checksum, :width, :height])
    |> validate_required([:id])
    |> validate_number(:id, greater_than: 0)
    |> validate_number(:byte_size, greater_than: 0)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_length(:checksum, max: 255)
  end
end
