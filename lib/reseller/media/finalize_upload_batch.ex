defmodule Reseller.Media.FinalizeUploadBatch do
  use Ecto.Schema
  import Ecto.Changeset

  alias Reseller.Media.FinalizeUploadSpec

  embedded_schema do
    embeds_many :uploads, FinalizeUploadSpec
  end

  def changeset(batch, attrs) do
    batch
    |> cast(attrs, [])
    |> cast_embed(:uploads, required: true, with: &FinalizeUploadSpec.changeset/2)
    |> validate_length(:uploads, min: 1, max: 5)
    |> validate_unique_upload_ids()
  end

  defp validate_unique_upload_ids(changeset) do
    uploads = get_field(changeset, :uploads, [])
    ids = Enum.map(uploads, & &1.id)

    if length(ids) == length(Enum.uniq(ids)) do
      changeset
    else
      add_error(changeset, :uploads, "contains duplicate image ids")
    end
  end
end
