defmodule Reseller.Imports.ZipParser do
  @moduledoc """
  Parses ResellerIO export ZIP archives into product payloads and image binaries.
  """

  def parse_archive(archive_binary) when is_binary(archive_binary) do
    with {:ok, entries} <- extract_entries(archive_binary),
         {:ok, manifest_payload} <- decode_manifest(entries),
         {:ok, products} <- fetch_products(manifest_payload) do
      {:ok,
       %{
         products: products,
         images:
           entries
           |> Map.delete("manifest.json")
           |> Map.delete("index.json")
           |> Map.delete("Products.xls")
       }}
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp extract_entries(archive_binary) do
    zip_path =
      Path.join(System.tmp_dir!(), "resellerio-import-#{System.unique_integer([:positive])}.zip")

    try do
      :ok = File.write!(zip_path, archive_binary)

      case :zip.extract(String.to_charlist(zip_path), [:memory]) do
        {:ok, entries} ->
          {:ok,
           Map.new(entries, fn {name, body} ->
             {to_string(name), body}
           end)}

        {:error, reason} ->
          {:error, {:invalid_zip_archive, reason}}
      end
    after
      File.rm(zip_path)
    end
  end

  defp decode_manifest(entries) do
    entries
    |> Map.fetch("manifest.json")
    |> case do
      {:ok, manifest_json} -> decode_manifest_json(manifest_json, :invalid_manifest_json)
      :error -> decode_legacy_index(entries)
    end
  end

  defp decode_legacy_index(entries) do
    case Map.fetch(entries, "index.json") do
      {:ok, index_json} -> decode_manifest_json(index_json, :invalid_index_json)
      :error -> {:error, :missing_manifest_json}
    end
  end

  defp decode_manifest_json(payload_json, error_tag) do
    case Jason.decode(payload_json) do
      {:ok, payload} when is_map(payload) -> {:ok, payload}
      {:error, reason} -> {:error, {error_tag, reason}}
    end
  end

  defp fetch_products(%{"products" => products}) when is_list(products), do: {:ok, products}
  defp fetch_products(_payload), do: {:error, :invalid_products_payload}
end
