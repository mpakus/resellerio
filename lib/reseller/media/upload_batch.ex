defmodule Reseller.Media.UploadBatch do
  use Ecto.Schema
  import Ecto.Changeset

  alias Reseller.Media.UploadSpec

  embedded_schema do
    embeds_many :uploads, UploadSpec
  end

  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [])
    |> cast_embed(:uploads, required: true, with: &UploadSpec.changeset/2)
    |> validate_length(:uploads, min: 1, max: 5)
  end
end
