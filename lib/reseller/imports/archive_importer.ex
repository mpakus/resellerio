defmodule Reseller.Imports.ArchiveImporter do
  @moduledoc """
  Recreates products and media from parsed reseller ZIP archives.
  """

  alias Reseller.Accounts.User
  alias Reseller.AI.ProductDescriptionDraft
  alias Reseller.AI.ProductPriceResearch
  alias Reseller.Catalog
  alias Reseller.Catalog.Product
  alias Reseller.Marketplaces.MarketplaceListing
  alias Reseller.Media.ProductImage
  alias Reseller.Media.Storage
  alias Reseller.Repo

  def import_user_archive(%User{} = user, %{products: products, images: images}, opts \\ [])
      when is_list(products) and is_map(images) do
    summary =
      products
      |> Enum.with_index(1)
      |> Enum.reduce(
        %{created_product_ids: [], failed_products: 0, failures: [], imported_products: 0},
        fn {product_payload, index}, acc ->
          case import_product(user, product_payload, images, opts) do
            {:ok, product} ->
              %{
                acc
                | imported_products: acc.imported_products + 1,
                  created_product_ids: acc.created_product_ids ++ [product.id]
              }

            {:error, reason} ->
              %{
                acc
                | failed_products: acc.failed_products + 1,
                  failures: acc.failures ++ [build_failure(index, product_payload, reason)]
              }
          end
        end
      )

    {:ok, Map.put(summary, :total_products, length(products))}
  end

  defp import_product(%User{} = user, product_payload, images, opts) do
    Repo.transaction(fn ->
      with {:ok, product} <- insert_product(user, product_payload),
           :ok <- insert_images(product, Map.get(product_payload, "images", []), images, opts),
           :ok <-
             insert_description_draft(product, Map.get(product_payload, "description_draft")),
           :ok <- insert_price_research(product, Map.get(product_payload, "price_research")),
           :ok <-
             insert_marketplace_listings(
               product,
               Map.get(product_payload, "marketplace_listings", [])
             ) do
        Catalog.get_product_for_user(user, product.id)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, product} -> {:ok, product}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_product(%User{} = user, payload) when is_map(payload) do
    %Product{}
    |> Product.create_changeset(product_attrs(payload))
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  defp insert_images(_product, [], _images, _opts), do: :ok

  defp insert_images(%Product{} = product, image_payloads, images, opts)
       when is_list(image_payloads) do
    Enum.reduce_while(image_payloads, :ok, fn image_payload, :ok ->
      case insert_image(product, image_payload, images, opts) do
        {:ok, _image} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp insert_image(%Product{} = product, payload, images, opts) when is_map(payload) do
    with {:ok, body} <- image_body(payload, images),
         storage_key = build_image_storage_key(product, payload),
         {:ok, _upload} <-
           Storage.upload_object(
             storage_key,
             body,
             content_type: image_content_type(payload),
             provider: Keyword.get(opts, :storage, Storage.provider())
           ) do
      %ProductImage{}
      |> ProductImage.create_changeset(image_attrs(payload, storage_key, body))
      |> Ecto.Changeset.put_assoc(:product, product)
      |> Repo.insert()
    end
  end

  defp insert_description_draft(_product, nil), do: :ok

  defp insert_description_draft(%Product{} = product, payload) when is_map(payload) do
    %ProductDescriptionDraft{}
    |> ProductDescriptionDraft.create_changeset(%{
      "status" => normalize_generated_status(payload["status"]),
      "provider" => "import",
      "model" => "zip-import",
      "suggested_title" => payload["suggested_title"],
      "short_description" => payload["short_description"] || payload["long_description"],
      "long_description" => payload["long_description"],
      "key_features" => List.wrap(payload["key_features"]),
      "seo_keywords" => List.wrap(payload["seo_keywords"]),
      "missing_details_warning" => payload["missing_details_warning"],
      "raw_payload" => payload
    })
    |> Ecto.Changeset.put_assoc(:product, product)
    |> Repo.insert()
    |> normalize_insert_result()
  end

  defp insert_price_research(_product, nil), do: :ok

  defp insert_price_research(%Product{} = product, payload) when is_map(payload) do
    %ProductPriceResearch{}
    |> ProductPriceResearch.create_changeset(%{
      "status" => normalize_generated_status(payload["status"]),
      "provider" => "import",
      "model" => "zip-import",
      "currency" => payload["currency"] || "USD",
      "suggested_min_price" => payload["suggested_min_price"],
      "suggested_target_price" => payload["suggested_target_price"],
      "suggested_max_price" => payload["suggested_max_price"],
      "suggested_median_price" => payload["suggested_median_price"],
      "pricing_confidence" => payload["pricing_confidence"],
      "rationale_summary" => payload["rationale_summary"],
      "market_signals" => List.wrap(payload["market_signals"]),
      "comparable_results" => %{"items" => List.wrap(payload["comparable_results"])},
      "raw_payload" => payload
    })
    |> Ecto.Changeset.put_assoc(:product, product)
    |> Repo.insert()
    |> normalize_insert_result()
  end

  defp insert_marketplace_listings(_product, []), do: :ok

  defp insert_marketplace_listings(%Product{} = product, listings) when is_list(listings) do
    Enum.reduce_while(listings, :ok, fn listing_payload, :ok ->
      case insert_marketplace_listing(product, listing_payload) do
        {:ok, _listing} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp insert_marketplace_listing(%Product{} = product, payload) when is_map(payload) do
    %MarketplaceListing{}
    |> MarketplaceListing.create_changeset(%{
      "marketplace" => payload["marketplace"],
      "status" => normalize_generated_status(payload["status"]),
      "generated_title" => payload["generated_title"],
      "generated_description" => payload["generated_description"],
      "generated_tags" => List.wrap(payload["generated_tags"]),
      "generated_price_suggestion" => payload["generated_price_suggestion"],
      "generation_version" => payload["generation_version"] || "zip-import",
      "compliance_warnings" => List.wrap(payload["compliance_warnings"]),
      "raw_payload" => payload,
      "last_generated_at" => now()
    })
    |> Ecto.Changeset.put_assoc(:product, product)
    |> Repo.insert()
  end

  defp image_body(payload, images) do
    case Map.get(payload, "path") do
      path when is_binary(path) ->
        case Map.fetch(images, path) do
          {:ok, body} -> {:ok, body}
          :error -> {:error, {:missing_image, path}}
        end

      _other ->
        {:error, :missing_image_path}
    end
  end

  defp image_attrs(payload, storage_key, body) do
    %{
      "kind" => payload["kind"] || "original",
      "position" => payload["position"] || 1,
      "storage_key" => storage_key,
      "content_type" => image_content_type(payload),
      "byte_size" => byte_size(body),
      "background_style" => payload["background_style"],
      "processing_status" => normalize_processing_status(payload["processing_status"]),
      "original_filename" => payload["path"] |> Path.basename()
    }
  end

  defp build_image_storage_key(%Product{} = product, payload) do
    extension =
      payload
      |> Map.get("path", "")
      |> Path.extname()
      |> case do
        "" -> extension_from_content_type(image_content_type(payload))
        ext -> ext
      end

    kind = payload["kind"] || "original"
    position = payload["position"] || 1

    "users/#{product.user_id}/products/#{product.id}/imports/#{position}-#{kind}-#{Ecto.UUID.generate()}#{extension}"
  end

  defp image_content_type(payload) do
    payload["content_type"] || content_type_from_path(payload["path"])
  end

  defp content_type_from_path(path) when is_binary(path) do
    case String.downcase(Path.extname(path)) do
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".webp" -> "image/webp"
      _other -> "image/jpeg"
    end
  end

  defp content_type_from_path(_path), do: "image/jpeg"

  defp extension_from_content_type("image/png"), do: ".png"
  defp extension_from_content_type("image/jpeg"), do: ".jpg"
  defp extension_from_content_type("image/webp"), do: ".webp"
  defp extension_from_content_type(_content_type), do: ".bin"

  defp product_attrs(payload) do
    %{
      "status" => normalize_product_status(payload["status"]),
      "source" => "import",
      "title" => payload["title"],
      "brand" => payload["brand"],
      "category" => payload["category"],
      "condition" => payload["condition"],
      "color" => payload["color"],
      "size" => payload["size"],
      "material" => payload["material"],
      "price" => payload["price"],
      "cost" => payload["cost"],
      "sku" => payload["sku"],
      "tags" => payload["tags"],
      "notes" => payload["notes"],
      "ai_summary" => payload["ai_summary"],
      "ai_confidence" => payload["ai_confidence"]
    }
  end

  defp normalize_product_status(status) when status in ~w(draft review ready sold archived),
    do: status

  defp normalize_product_status(status) when status in ~w(uploading processing), do: "review"
  defp normalize_product_status(_status), do: "draft"

  defp normalize_processing_status("failed"), do: "failed"
  defp normalize_processing_status(_status), do: "ready"

  defp normalize_generated_status(status) when status in ~w(generated review failed), do: status
  defp normalize_generated_status(_status), do: "generated"

  defp build_failure(index, payload, reason) do
    %{
      "index" => index,
      "title" => payload["title"],
      "sku" => payload["sku"],
      "reason" => format_reason(reason)
    }
  end

  defp format_reason({:missing_image, path}), do: "Missing image entry: #{path}"
  defp format_reason(:missing_image_path), do: "Image path is missing from the archive payload"
  defp format_reason(%Ecto.Changeset{} = changeset), do: inspect(changeset.errors)
  defp format_reason(reason), do: inspect(reason)

  defp normalize_insert_result({:ok, _record}), do: :ok
  defp normalize_insert_result({:error, reason}), do: {:error, reason}

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
