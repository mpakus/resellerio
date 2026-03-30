defmodule Reseller.Exports.ZipBuilder do
  @moduledoc """
  Builds product export ZIP archives with `index.json` and `images/*`.
  """

  alias Reseller.Accounts.User
  alias Reseller.Catalog
  alias Reseller.Media

  @spec build_user_export(User.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def build_user_export(%User{} = user, opts \\ []) do
    products = Catalog.list_products_for_user(user)

    with {:ok, image_entries, product_payloads} <- image_entries(products, opts),
         {:ok, zip_binary} <- build_zip(product_payloads, image_entries) do
      {:ok, zip_binary}
    end
  end

  defp image_entries(products, opts) do
    products
    |> Enum.reduce_while({:ok, [], []}, fn product, {:ok, entries, payloads} ->
      case product_image_entries(product, opts) do
        {:ok, product_entries, image_payloads} ->
          payload =
            product
            |> export_product_payload(image_payloads)

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
            "content_type" => image.content_type,
            "background_style" => image.background_style,
            "processing_status" => image.processing_status,
            "path" => image_path
          }

          {:cont,
           {:ok, entries ++ [{String.to_charlist(image_path), body}], payloads ++ [image_payload]}}

        {:error, reason} ->
          {:halt, {:error, {:image_download_failed, image.id, reason}}}
      end
    end)
  end

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
      "notes" => product.notes,
      "ai_summary" => product.ai_summary,
      "ai_confidence" => product.ai_confidence,
      "description_draft" => description_draft_payload(product.description_draft),
      "price_research" => price_research_payload(product.price_research),
      "marketplace_listings" =>
        Enum.map(product.marketplace_listings || [], &marketplace_listing_payload/1),
      "images" => image_payloads
    }
  end

  defp build_zip(product_payloads, image_entries) do
    index_json = Jason.encode!(%{"products" => product_payloads}, pretty: true)
    entries = [{~c"index.json", index_json}] ++ image_entries

    case :zip.create(~c"resellerio-export.zip", entries, [:memory]) do
      {:ok, {_name, zip_binary}} -> {:ok, zip_binary}
      {:error, reason} -> {:error, {:zip_create_failed, reason}}
    end
  end

  defp download_image(image, opts) do
    image
    |> Media.public_url_for_image(opts)
    |> case do
      {:ok, image_url} -> do_download_image(image_url, opts)
      {:error, reason} -> {:error, reason}
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
    "images/#{product.id}/#{image.position}-#{image.kind}#{image_extension(image)}"
  end

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
      "suggested_title" => draft.suggested_title,
      "short_description" => draft.short_description,
      "long_description" => draft.long_description,
      "key_features" => draft.key_features,
      "seo_keywords" => draft.seo_keywords,
      "missing_details_warning" => draft.missing_details_warning
    }
  end

  defp price_research_payload(nil), do: nil

  defp price_research_payload(price_research) do
    %{
      "status" => price_research.status,
      "currency" => price_research.currency,
      "suggested_min_price" => decimal_to_string(price_research.suggested_min_price),
      "suggested_target_price" => decimal_to_string(price_research.suggested_target_price),
      "suggested_max_price" => decimal_to_string(price_research.suggested_max_price),
      "suggested_median_price" => decimal_to_string(price_research.suggested_median_price),
      "pricing_confidence" => price_research.pricing_confidence,
      "rationale_summary" => price_research.rationale_summary
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
      "compliance_warnings" => listing.compliance_warnings
    }
  end

  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)
end
