defmodule ResellerWeb.API.V1.ProductController do
  use ResellerWeb, :controller

  alias Reseller.Catalog
  alias ResellerWeb.APIError

  def index(conn, _params) do
    products = Catalog.list_products_for_user(conn.assigns.current_user)
    json(conn, %{data: %{products: Enum.map(products, &product_json/1)}})
  end

  def show(conn, %{"id" => id}) do
    case Catalog.get_product_for_user(conn.assigns.current_user, id) do
      nil ->
        APIError.render(conn, :not_found, "not_found", "Product not found")

      product ->
        json(conn, %{data: %{product: product_json(product)}})
    end
  end

  def update(conn, %{"id" => product_id} = params) do
    product_attrs = Map.get(params, "product", %{})

    case Catalog.update_product_for_user(conn.assigns.current_user, product_id, product_attrs) do
      {:ok, product} ->
        json(conn, %{data: %{product: product_json(product)}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Product not found")

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)
    end
  end

  def delete(conn, %{"id" => product_id}) do
    case Catalog.delete_product_for_user(conn.assigns.current_user, product_id) do
      {:ok, _product} ->
        json(conn, %{data: %{deleted: true}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Product not found")
    end
  end

  def create(conn, params) do
    product_attrs = Map.get(params, "product", %{})
    uploads = Map.get(params, "uploads", [])

    case Catalog.create_product_for_user(conn.assigns.current_user, product_attrs, uploads) do
      {:ok, %{product: product, upload_bundle: upload_bundle}} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            product: product_json(product),
            upload_instructions: upload_bundle.upload_instructions
          }
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, {:missing_config, config_key}} ->
        APIError.render(
          conn,
          :bad_gateway,
          "storage_unavailable",
          "Storage upload signing is not configured: #{config_key}"
        )

      {:error, reason} ->
        APIError.render(
          conn,
          :bad_gateway,
          "upload_signing_failed",
          "Upload signing failed: #{inspect(reason)}"
        )
    end
  end

  def finalize_uploads(conn, %{"id" => product_id} = params) do
    uploads = Map.get(params, "uploads", [])

    case Catalog.finalize_product_uploads_for_user(conn.assigns.current_user, product_id, uploads) do
      {:ok,
       %{product: product, finalized_images: finalized_images, processing_run: processing_run}} ->
        json(conn, %{
          data: %{
            product: product_json(product),
            finalized_images: Enum.map(finalized_images, &image_json/1),
            processing_run: processing_run && processing_run_json(processing_run)
          }
        })

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Product not found")

      {:error, :no_product_images} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "invalid_product_state",
          "Product has no images to finalize"
        )

      {:error, :invalid_product_images} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "invalid_uploads",
          "Uploads must belong to the selected product"
        )

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)

      {:error, reason} ->
        APIError.render(
          conn,
          :unprocessable_entity,
          "finalize_failed",
          "Could not finalize uploads: #{inspect(reason)}"
        )
    end
  end

  def mark_sold(conn, %{"id" => product_id} = params) do
    product_attrs = Map.get(params, "product", %{})

    case Catalog.mark_product_sold_for_user(conn.assigns.current_user, product_id, product_attrs) do
      {:ok, product} ->
        json(conn, %{data: %{product: product_json(product)}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Product not found")

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)
    end
  end

  def archive(conn, %{"id" => product_id}) do
    case Catalog.archive_product_for_user(conn.assigns.current_user, product_id) do
      {:ok, product} ->
        json(conn, %{data: %{product: product_json(product)}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Product not found")

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)
    end
  end

  def unarchive(conn, %{"id" => product_id}) do
    case Catalog.unarchive_product_for_user(conn.assigns.current_user, product_id) do
      {:ok, product} ->
        json(conn, %{data: %{product: product_json(product)}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Product not found")

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)
    end
  end

  defp product_json(product) do
    %{
      id: product.id,
      status: product.status,
      source: product.source,
      title: product.title,
      brand: product.brand,
      category: product.category,
      condition: product.condition,
      color: product.color,
      size: product.size,
      material: product.material,
      price: decimal_to_string(product.price),
      cost: decimal_to_string(product.cost),
      sku: product.sku,
      notes: product.notes,
      ai_summary: product.ai_summary,
      ai_confidence: product.ai_confidence,
      sold_at: datetime_to_iso8601(product.sold_at),
      archived_at: datetime_to_iso8601(product.archived_at),
      inserted_at: datetime_to_iso8601(product.inserted_at),
      updated_at: datetime_to_iso8601(product.updated_at),
      latest_processing_run:
        product.processing_runs
        |> List.first()
        |> case do
          nil -> nil
          run -> processing_run_json(run)
        end,
      description_draft: description_draft_json(product.description_draft),
      price_research: price_research_json(product.price_research),
      marketplace_listings:
        Enum.map(product.marketplace_listings || [], &marketplace_listing_json/1),
      images: Enum.map(product.images || [], &image_json/1)
    }
  end

  defp image_json(image) do
    %{
      id: image.id,
      kind: image.kind,
      position: image.position,
      storage_key: image.storage_key,
      content_type: image.content_type,
      width: image.width,
      height: image.height,
      byte_size: image.byte_size,
      checksum: image.checksum,
      background_style: image.background_style,
      processing_status: image.processing_status,
      original_filename: image.original_filename,
      inserted_at: datetime_to_iso8601(image.inserted_at),
      updated_at: datetime_to_iso8601(image.updated_at)
    }
  end

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)

  defp processing_run_json(run) do
    %{
      id: run.id,
      status: run.status,
      step: run.step,
      started_at: datetime_to_iso8601(run.started_at),
      finished_at: datetime_to_iso8601(run.finished_at),
      error_code: run.error_code,
      error_message: run.error_message,
      inserted_at: datetime_to_iso8601(run.inserted_at),
      updated_at: datetime_to_iso8601(run.updated_at),
      payload: run.payload
    }
  end

  defp description_draft_json(nil), do: nil

  defp description_draft_json(draft) do
    %{
      id: draft.id,
      status: draft.status,
      provider: draft.provider,
      model: draft.model,
      suggested_title: draft.suggested_title,
      short_description: draft.short_description,
      long_description: draft.long_description,
      key_features: draft.key_features,
      seo_keywords: draft.seo_keywords,
      missing_details_warning: draft.missing_details_warning,
      inserted_at: datetime_to_iso8601(draft.inserted_at),
      updated_at: datetime_to_iso8601(draft.updated_at)
    }
  end

  defp price_research_json(nil), do: nil

  defp price_research_json(price_research) do
    %{
      id: price_research.id,
      status: price_research.status,
      provider: price_research.provider,
      model: price_research.model,
      currency: price_research.currency,
      suggested_min_price: decimal_to_string(price_research.suggested_min_price),
      suggested_target_price: decimal_to_string(price_research.suggested_target_price),
      suggested_max_price: decimal_to_string(price_research.suggested_max_price),
      suggested_median_price: decimal_to_string(price_research.suggested_median_price),
      pricing_confidence: price_research.pricing_confidence,
      rationale_summary: price_research.rationale_summary,
      market_signals: price_research.market_signals,
      comparable_results: Map.get(price_research.comparable_results || %{}, "items", []),
      inserted_at: datetime_to_iso8601(price_research.inserted_at),
      updated_at: datetime_to_iso8601(price_research.updated_at)
    }
  end

  defp marketplace_listing_json(listing) do
    %{
      id: listing.id,
      marketplace: listing.marketplace,
      status: listing.status,
      generated_title: listing.generated_title,
      generated_description: listing.generated_description,
      generated_tags: listing.generated_tags,
      generated_price_suggestion: decimal_to_string(listing.generated_price_suggestion),
      generation_version: listing.generation_version,
      compliance_warnings: listing.compliance_warnings,
      last_generated_at: datetime_to_iso8601(listing.last_generated_at),
      inserted_at: datetime_to_iso8601(listing.inserted_at),
      updated_at: datetime_to_iso8601(listing.updated_at)
    }
  end
end
