defmodule Reseller.Exports.ZipBuilder do
  @moduledoc """
  Builds product export ZIP archives with `Products.xls`, `manifest.json`, and `images/*`.
  """

  alias Reseller.Accounts.User
  alias Reseller.Catalog
  alias Reseller.Exports
  alias Reseller.Exports.Export
  alias Reseller.Exports.Spreadsheet
  alias Reseller.Media
  alias Reseller.Media.Storage

  @spec build_export(Export.t(), User.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def build_export(%Export{} = export, %User{} = user, opts \\ []) do
    products =
      Catalog.list_filtered_products_for_user(
        user,
        Exports.filter_params_to_catalog_opts(export.filter_params || %{})
      )

    with {:ok, image_entries, product_payloads} <- image_entries(products, opts),
         manifest <- export_manifest(export, product_payloads),
         workbook_xml <- Spreadsheet.build_workbook(export, manifest),
         {:ok, zip_binary} <- build_zip(manifest, workbook_xml, image_entries) do
      {:ok, zip_binary}
    end
  end

  defp image_entries(products, opts) do
    products
    |> Enum.reduce_while({:ok, [], []}, fn product, {:ok, entries, payloads} ->
      case product_image_entries(product, opts) do
        {:ok, product_entries, image_payloads} ->
          payload = export_product_payload(product, image_payloads)
          {:cont, {:ok, entries ++ product_entries, payloads ++ [payload]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp product_image_entries(product, opts) do
    product.images
    |> Enum.reduce_while({:ok, [], []}, fn image, {:ok, entries, payloads} ->
      image_path = image_export_path(product, image)

      case download_image(image, opts) do
        {:ok, body} ->
          image_payload = %{
            "id" => image.id,
            "kind" => image.kind,
            "position" => image.position,
            "filename" => Path.basename(image_path),
            "path" => image_path,
            "storage_key" => image.storage_key,
            "content_type" => image.content_type,
            "width" => image.width,
            "height" => image.height,
            "byte_size" => image.byte_size,
            "checksum" => image.checksum,
            "background_style" => image.background_style,
            "processing_status" => image.processing_status,
            "original_filename" => image.original_filename,
            "scene_key" => image.scene_key,
            "variant_index" => image.variant_index,
            "source_image_ids" => image.source_image_ids || [],
            "seller_approved" => image.seller_approved,
            "approved_at" => datetime_to_iso8601(image.approved_at)
          }

          {:cont,
           {:ok, entries ++ [{String.to_charlist(image_path), body}], payloads ++ [image_payload]}}

        {:error, reason} ->
          {:halt, {:error, {:image_download_failed, image.id, reason}}}
      end
    end)
  end

  @spec export_product_payload(struct()) :: map()
  def export_product_payload(product), do: export_product_payload(product, [])

  defp export_product_payload(product, image_payloads) do
    %{
      "id" => product.id,
      "status" => product.status,
      "source" => product.source,
      "title" => product.title,
      "brand" => product.brand,
      "category" => product.category,
      "condition" => product.condition,
      "color" => product.color,
      "size" => product.size,
      "material" => product.material,
      "price" => decimal_to_string(product.price),
      "cost" => decimal_to_string(product.cost),
      "sku" => product.sku,
      "tags" => product.tags || [],
      "notes" => product.notes,
      "ai_summary" => product.ai_summary,
      "ai_confidence" => product.ai_confidence,
      "sold_at" => datetime_to_iso8601(product.sold_at),
      "archived_at" => datetime_to_iso8601(product.archived_at),
      "inserted_at" => datetime_to_iso8601(product.inserted_at),
      "updated_at" => datetime_to_iso8601(product.updated_at),
      "description_draft" => description_draft_payload(product.description_draft),
      "price_research" => price_research_payload(product.price_research),
      "marketplace_listings" =>
        Enum.map(product.marketplace_listings || [], &marketplace_listing_payload/1),
      "images" => image_payloads
    }
  end

  defp export_manifest(%Export{} = export, product_payloads) do
    %{
      "export" => %{
        "id" => export.id,
        "name" => export.name,
        "file_name" => export.file_name,
        "requested_at" => datetime_to_iso8601(export.requested_at),
        "filter_params" => export.filter_params || %{},
        "product_count" => length(product_payloads)
      },
      "products" => product_payloads
    }
  end

  defp build_zip(manifest, workbook_xml, image_entries) do
    manifest_json = Jason.encode!(manifest, pretty: true)

    entries =
      [
        {~c"Products.xls", workbook_xml},
        {~c"manifest.json", manifest_json}
      ] ++ image_entries

    case :zip.create(~c"resellerio-export.zip", entries, [:memory]) do
      {:ok, {_name, zip_binary}} -> {:ok, zip_binary}
      {:error, reason} -> {:error, {:zip_create_failed, reason}}
    end
  end

  defp download_image(image, opts) do
    with {:ok, image_url} <- image_download_url(image, opts) do
      do_download_image(image_url, opts)
    end
  end

  defp image_download_url(image, opts) do
    storage_opts =
      [
        provider: Keyword.get(opts, :storage, Storage.provider())
      ] ++
        Keyword.take(opts, [
          :request_time,
          :expires_in,
          :config,
          :sign_download_result,
          :public_base_url
        ])

    case Storage.sign_download(image.storage_key, storage_opts) do
      {:ok, payload} ->
        case Map.get(payload, :download_url) || Map.get(payload, "download_url") do
          image_url when is_binary(image_url) -> {:ok, image_url}
          _other -> Media.public_url_for_image(image, opts)
        end

      {:error, _reason} ->
        Media.public_url_for_image(image, opts)
    end
  end

  defp do_download_image(image_url, opts) do
    request_fun = Keyword.get(opts, :download_request_fun, &default_download_request/1)

    case request_fun.(image_url) do
      {:ok, %{status: status, body: body}} when status in 200..299 and is_binary(body) ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp default_download_request(image_url) do
    Req.get(url: image_url)
  end

  defp image_export_path(product, image) do
    extension = image_extension(image)
    base_name = image.original_filename |> image_file_stem() |> maybe_append_extension(extension)

    case base_name do
      nil ->
        "images/#{product.id}/#{image.position}-#{image.kind}#{extension}"

      value ->
        "images/#{product.id}/#{image.position}-#{image.kind}-#{value}"
    end
  end

  defp image_file_stem(nil), do: nil

  defp image_file_stem(original_filename) when is_binary(original_filename) do
    original_filename
    |> Path.rootname()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp maybe_append_extension(nil, _extension), do: nil
  defp maybe_append_extension(base_name, extension), do: base_name <> extension

  defp image_extension(image) do
    Path.extname(image.storage_key || "")
    |> case do
      "" -> extension_from_content_type(image.content_type)
      ext -> ext
    end
  end

  defp extension_from_content_type("image/png"), do: ".png"
  defp extension_from_content_type("image/jpeg"), do: ".jpg"
  defp extension_from_content_type("image/webp"), do: ".webp"
  defp extension_from_content_type(_type), do: ".bin"

  defp description_draft_payload(nil), do: nil

  defp description_draft_payload(draft) do
    %{
      "status" => draft.status,
      "provider" => draft.provider,
      "model" => draft.model,
      "suggested_title" => draft.suggested_title,
      "short_description" => draft.short_description,
      "long_description" => draft.long_description,
      "key_features" => draft.key_features,
      "seo_keywords" => draft.seo_keywords,
      "missing_details_warning" => draft.missing_details_warning,
      "raw_payload" => draft.raw_payload || %{}
    }
  end

  defp price_research_payload(nil), do: nil

  defp price_research_payload(price_research) do
    %{
      "status" => price_research.status,
      "provider" => price_research.provider,
      "model" => price_research.model,
      "currency" => price_research.currency,
      "suggested_min_price" => decimal_to_string(price_research.suggested_min_price),
      "suggested_target_price" => decimal_to_string(price_research.suggested_target_price),
      "suggested_max_price" => decimal_to_string(price_research.suggested_max_price),
      "suggested_median_price" => decimal_to_string(price_research.suggested_median_price),
      "pricing_confidence" => price_research.pricing_confidence,
      "rationale_summary" => price_research.rationale_summary,
      "market_signals" => price_research.market_signals || [],
      "comparable_results" => price_research.comparable_results || %{},
      "raw_payload" => price_research.raw_payload || %{}
    }
  end

  defp marketplace_listing_payload(listing) do
    %{
      "marketplace" => listing.marketplace,
      "status" => listing.status,
      "generated_title" => listing.generated_title,
      "generated_description" => listing.generated_description,
      "generated_tags" => listing.generated_tags,
      "generated_price_suggestion" => decimal_to_string(listing.generated_price_suggestion),
      "generation_version" => listing.generation_version,
      "compliance_warnings" => listing.compliance_warnings,
      "raw_payload" => listing.raw_payload || %{},
      "last_generated_at" => datetime_to_iso8601(listing.last_generated_at)
    }
  end

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)
end
