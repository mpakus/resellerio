defmodule Reseller.Imports.ZipParser do
  @moduledoc """
  Parses reseller export ZIP archives into product payloads and image binaries.
  """

  def parse_archive(archive_binary) when is_binary(archive_binary) do
    with {:ok, entries} <- extract_entries(archive_binary),
         {:ok, index_payload} <- decode_index(entries),
         {:ok, products} <- fetch_products(index_payload) do
      {:ok,
       %{
         products: products,
         images: Map.delete(entries, "index.json")
       }}
    end
  end

  defp extract_entries(archive_binary) do
    zip_path =
      Path.join(System.tmp_dir!(), "reseller-import-#{System.unique_integer([:positive])}.zip")

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

  defp decode_index(entries) do
    case Map.fetch(entries, "index.json") do
      {:ok, index_json} ->
        case Jason.decode(index_json) do
          {:ok, payload} when is_map(payload) -> {:ok, payload}
          {:error, reason} -> {:error, {:invalid_index_json, reason}}
        end

      :error ->
        {:error, :missing_index_json}
    end
  end

  defp fetch_products(%{"products" => products}) when is_list(products), do: {:ok, products}
  defp fetch_products(_payload), do: {:error, :invalid_products_payload}
end
