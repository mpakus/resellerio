defmodule Reseller.Imports.ImportRequest do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :filename, :string
    field :archive_base64, :string
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [:filename, :archive_base64])
    |> validate_required([:filename, :archive_base64])
    |> validate_length(:filename, max: 255)
    |> validate_format(:filename, ~r/\.zip$/i, message: "must be a .zip archive")
    |> validate_change(:archive_base64, fn :archive_base64, archive_base64 ->
      case Base.decode64(archive_base64) do
        {:ok, binary} ->
          if byte_size(binary) <= max_archive_bytes() do
            []
          else
            [archive_base64: "must be #{max_archive_bytes()} bytes or smaller after decoding"]
          end

        :error ->
          [archive_base64: "must be valid base64"]
      end
    end)
  end

  def validated_attrs(attrs) when is_map(attrs) do
    changeset = changeset(%__MODULE__{}, attrs)

    if changeset.valid? do
      {:ok,
       %{
         filename: get_field(changeset, :filename),
         archive_binary: Base.decode64!(get_field(changeset, :archive_base64))
       }}
    else
      {:error, changeset}
    end
  end

  defp max_archive_bytes do
    Application.get_env(:reseller, Reseller.Imports, [])[:max_archive_bytes] || 25_000_000
  end
end
