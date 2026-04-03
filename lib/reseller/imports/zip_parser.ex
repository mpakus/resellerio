defmodule Reseller.Imports.ZipParser do
  @moduledoc """
  Parses ResellerIO export ZIP archives into product payloads and image binaries.
  """

  def parse_archive(archive_binary) when is_binary(archive_binary) do
    with {:ok, entries} <- extract_entries(archive_binary),
         :ok <- validate_entries(entries),
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

  defp validate_entries(entries) when is_map(entries) do
    max_entry_count = import_cfg(:max_entry_count, 500)
    max_entry_bytes = import_cfg(:max_entry_bytes, 15_000_000)
    max_total_bytes = import_cfg(:max_total_uncompressed_bytes, 75_000_000)

    cond do
      map_size(entries) > max_entry_count ->
        {:error, :archive_too_many_entries}

      Enum.any?(entries, fn {name, _body} -> not safe_entry_name?(name) end) ->
        {:error, :invalid_archive_entry_path}

      Enum.any?(entries, fn {_name, body} -> byte_size(body) > max_entry_bytes end) ->
        {:error, :archive_entry_too_large}

      Enum.reduce(entries, 0, fn {_name, body}, acc -> acc + byte_size(body) end) >
          max_total_bytes ->
        {:error, :archive_uncompressed_size_exceeded}

      true ->
        :ok
    end
  end

  defp safe_entry_name?(name) when is_binary(name) do
    name_type = Path.type(name)

    name != "" and name_type == :relative and not String.contains?(name, "\\") and
      not String.contains?(name, <<0>>) and
      Enum.all?(String.split(name, "/", trim: true), &(&1 not in [".", ".."]))
  end

  defp safe_entry_name?(_name), do: false

  defp import_cfg(key, default) do
    Application.get_env(:reseller, Reseller.Imports, [])[key] || default
  end
end
