defmodule ResellerWeb.API.V1.ProductController do
  use ResellerWeb, :controller

  alias Reseller.Catalog
  alias Reseller.Metrics
  alias ResellerWeb.APIError

  def index(conn, params) do
    product_page =
      Catalog.paginate_products_for_user(conn.assigns.current_user,
        page: Map.get(params, "page"),
        page_size: normalize_page_size(Map.get(params, "page_size")),
        status: Map.get(params, "status"),
        query: Map.get(params, "query"),
        product_tab_id: Map.get(params, "product_tab_id"),
        updated_from: parse_date(Map.get(params, "updated_from")),
        updated_to: parse_date(Map.get(params, "updated_to")),
        sort: Map.get(params, "sort"),
        sort_dir: Map.get(params, "dir")
      )

    json(conn, %{
      data: %{
        products: Enum.map(product_page.entries, &product_json/1),
        pagination: %{
          page: product_page.page,
          page_size: product_page.page_size,
          total_count: product_page.total_count,
          total_pages: product_page.total_pages
        },
        filters: %{
          status: product_page.status,
          query: product_page.query,
          product_tab_id: product_page.product_tab_id,
          updated_from: date_to_iso8601(product_page.updated_from),
          updated_to: date_to_iso8601(product_page.updated_to),
          sort: Atom.to_string(product_page.sort),
          dir: Atom.to_string(product_page.sort_dir)
        }
      }
    })
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
    raw_product_attrs = Map.get(params, "product", %{})
    product_attrs = Map.delete(raw_product_attrs, "marketplace_external_urls")

    marketplace_external_urls =
      case Map.get(params, "marketplace_external_urls") ||
             Map.get(raw_product_attrs, "marketplace_external_urls") do
        value when is_map(value) -> value
        _other -> %{}
      end

    case Catalog.update_product_review_for_user(
           conn.assigns.current_user,
           product_id,
           product_attrs,
           marketplace_external_urls
         ) do
      {:ok, product} ->
        json(conn, %{data: %{product: product_json(product)}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Product not found")

      {:error, {:marketplace_listing, marketplace, %Ecto.Changeset{} = changeset}} ->
        marketplace_external_url_validation(conn, marketplace, changeset)

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
          "Storage upload signing is not configured: #{humanize_config_key(config_key)}"
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
    with :ok <- Metrics.check_processing_limit(conn.assigns.current_user) do
      uploads = Map.get(params, "uploads", [])

      case Catalog.finalize_product_uploads_for_user(
             conn.assigns.current_user,
             product_id,
             uploads
           ) do
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
    else
      {:error, :limit_exceeded, details} ->
        render_limit_exceeded(conn, details)
    end
  end

  def prepare_uploads(conn, %{"id" => product_id} = params) do
    with :ok <- Metrics.check_processing_limit(conn.assigns.current_user) do
      uploads = Map.get(params, "uploads", [])

      case Catalog.prepare_product_uploads_for_user(
             conn.assigns.current_user,
             product_id,
             uploads
           ) do
        {:ok, %{product: product, upload_bundle: upload_bundle}} ->
          json(conn, %{
            data: %{
              product: product_json(product),
              upload_instructions: upload_bundle.upload_instructions
            }
          })

        {:error, :not_found} ->
          APIError.render(conn, :not_found, "not_found", "Product not found")

        {:error, :invalid_product_state} ->
          APIError.render(
            conn,
            :unprocessable_entity,
            "invalid_product_state",
            "Images can be changed only while the product is in draft, review, or ready"
          )

        {:error, %Ecto.Changeset{} = changeset} ->
          APIError.validation(conn, changeset)

        {:error, {:missing_config, config_key}} ->
          APIError.render(
            conn,
            :bad_gateway,
            "storage_unavailable",
            "Storage upload signing is not configured: #{humanize_config_key(config_key)}"
          )

        {:error, reason} ->
          APIError.render(
            conn,
            :bad_gateway,
            "upload_signing_failed",
            "Upload signing failed: #{inspect(reason)}"
          )
      end
    else
      {:error, :limit_exceeded, details} ->
        render_limit_exceeded(conn, details)
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

  def reprocess(conn, %{"id" => product_id}) do
    with :ok <- Metrics.check_processing_limit(conn.assigns.current_user) do
      case Catalog.retry_product_processing_for_user(conn.assigns.current_user, product_id) do
        {:ok, %{product: product, processing_run: processing_run}} ->
          conn
          |> put_status(:accepted)
          |> json(%{
            data: %{
              product: product_json(product),
              processing_run: processing_run_json(processing_run)
            }
          })

        {:error, :not_found} ->
          APIError.render(conn, :not_found, "not_found", "Product not found")

        {:error, :no_product_images} ->
          APIError.render(
            conn,
            :unprocessable_entity,
            "invalid_product_state",
            "Product has no images available for reprocessing"
          )

        {:error, %Ecto.Changeset{} = changeset} ->
          APIError.validation(conn, changeset)

        {:error, reason} ->
          APIError.render(
            conn,
            :unprocessable_entity,
            "reprocess_failed",
            "Could not restart processing: #{inspect(reason)}"
          )
      end
    else
      {:error, :limit_exceeded, details} ->
        render_limit_exceeded(conn, details)
    end
  end

  def generate_lifestyle_images(conn, %{"id" => product_id} = params) do
    with :ok <- Metrics.check_processing_limit(conn.assigns.current_user) do
      generation_opts =
        case Map.get(params, "scene_key") do
          scene_key when is_binary(scene_key) and scene_key != "" -> [scene_key: scene_key]
          _other -> []
        end

      case Catalog.generate_lifestyle_images_for_user(
             conn.assigns.current_user,
             product_id,
             generation_opts
           ) do
        {:ok, %{product: product, lifestyle_generation_run: lifestyle_generation_run}} ->
          conn
          |> put_status(:accepted)
          |> json(%{
            data: %{
              product: product_json(product),
              lifestyle_generation_run:
                lifestyle_generation_run &&
                  lifestyle_generation_run_json(lifestyle_generation_run)
            }
          })

        {:error, :not_found} ->
          APIError.render(conn, :not_found, "not_found", "Product not found")

        {:error, :no_product_images} ->
          APIError.render(
            conn,
            :unprocessable_entity,
            "invalid_product_state",
            "Product has no images available for lifestyle generation"
          )

        {:error, :invalid_product_state} ->
          APIError.render(
            conn,
            :unprocessable_entity,
            "invalid_product_state",
            "Lifestyle generation is only available after image processing has finished"
          )

        {:error, reason} ->
          APIError.render(
            conn,
            :unprocessable_entity,
            "lifestyle_generation_failed",
            "Could not start lifestyle generation: #{inspect(reason)}"
          )
      end
    else
      {:error, :limit_exceeded, details} ->
        render_limit_exceeded(conn, details)
    end
  end

  def lifestyle_generation_runs(conn, %{"id" => product_id}) do
    case Catalog.list_lifestyle_generation_runs_for_user(conn.assigns.current_user, product_id) do
      {:ok, runs} ->
        json(conn, %{data: %{runs: Enum.map(runs, &lifestyle_generation_run_json/1)}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Product not found")
    end
  end

  def approve_generated_image(conn, %{"id" => product_id, "image_id" => image_id}) do
    case parse_integer(image_id) do
      nil ->
        APIError.render(conn, :not_found, "not_found", "Generated image not found")

      parsed_image_id ->
        case Catalog.approve_lifestyle_image_for_user(
               conn.assigns.current_user,
               product_id,
               parsed_image_id
             ) do
          {:ok, product} ->
            json(conn, %{data: %{product: product_json(product)}})

          {:error, :not_found} ->
            APIError.render(conn, :not_found, "not_found", "Generated image not found")

          {:error, %Ecto.Changeset{} = changeset} ->
            APIError.validation(conn, changeset)
        end
    end
  end

  def delete_generated_image(conn, %{"id" => product_id, "image_id" => image_id}) do
    case parse_integer(image_id) do
      nil ->
        APIError.render(conn, :not_found, "not_found", "Generated image not found")

      parsed_image_id ->
        case Catalog.delete_lifestyle_image_for_user(
               conn.assigns.current_user,
               product_id,
               parsed_image_id
             ) do
          {:ok, product} ->
            json(conn, %{data: %{product: product_json(product), deleted: true}})

          {:error, :not_found} ->
            APIError.render(conn, :not_found, "not_found", "Generated image not found")
        end
    end
  end

  def delete_image(conn, %{"id" => product_id, "image_id" => image_id}) do
    case parse_integer(image_id) do
      nil ->
        APIError.render(conn, :not_found, "not_found", "Product image not found")

      parsed_image_id ->
        case Catalog.delete_product_image_for_user(
               conn.assigns.current_user,
               product_id,
               parsed_image_id
             ) do
          {:ok, product} ->
            json(conn, %{data: %{product: product_json(product), deleted: true}})

          {:error, :not_found} ->
            APIError.render(conn, :not_found, "not_found", "Product image not found")

          {:error, :invalid_product_state} ->
            APIError.render(
              conn,
              :unprocessable_entity,
              "invalid_product_state",
              "Images can be changed only while the product is in draft, review, or ready"
            )
        end
    end
  end

  def update_image_storefront(conn, %{"id" => product_id, "image_id" => image_id} = params) do
    case parse_integer(image_id) do
      nil ->
        APIError.render(conn, :not_found, "not_found", "Product image not found")

      parsed_image_id ->
        attrs = Map.take(params, ["storefront_visible", "storefront_position"])

        case Catalog.update_image_storefront_settings_for_user(
               conn.assigns.current_user,
               product_id,
               parsed_image_id,
               attrs
             ) do
          {:ok, product} ->
            json(conn, %{data: %{product: product_json(product)}})

          {:error, :not_found} ->
            APIError.render(conn, :not_found, "not_found", "Product or image not found")

          {:error, %Ecto.Changeset{} = changeset} ->
            APIError.validation(conn, changeset)
        end
    end
  end

  def reorder_storefront_images(conn, %{"id" => product_id, "image_ids" => image_ids})
      when is_list(image_ids) do
    parsed_ids = Enum.map(image_ids, &parse_integer/1) |> Enum.reject(&is_nil/1)

    case Catalog.reorder_storefront_images_for_user(
           conn.assigns.current_user,
           product_id,
           parsed_ids
         ) do
      {:ok, product} ->
        json(conn, %{data: %{product: product_json(product)}})

      {:error, :not_found} ->
        APIError.render(conn, :not_found, "not_found", "Product not found")

      {:error, reason} ->
        APIError.render(conn, :unprocessable_entity, "reorder_failed", inspect(reason))
    end
  end

  def reorder_storefront_images(conn, _params) do
    APIError.render(conn, :bad_request, "bad_request", "image_ids must be a list")
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
      product_tab_id: product.product_tab_id,
      product_tab: product_tab_json(product.product_tab),
      sku: product.sku,
      tags: product.tags || [],
      notes: product.notes,
      ai_summary: product.ai_summary,
      ai_confidence: product.ai_confidence,
      sold_at: datetime_to_iso8601(product.sold_at),
      archived_at: datetime_to_iso8601(product.archived_at),
      storefront_enabled: product.storefront_enabled,
      storefront_published_at: datetime_to_iso8601(product.storefront_published_at),
      inserted_at: datetime_to_iso8601(product.inserted_at),
      updated_at: datetime_to_iso8601(product.updated_at),
      latest_processing_run:
        product.processing_runs
        |> List.first()
        |> case do
          nil -> nil
          run -> processing_run_json(run)
        end,
      latest_lifestyle_generation_run:
        product.lifestyle_generation_runs
        |> List.first()
        |> case do
          nil -> nil
          run -> lifestyle_generation_run_json(run)
        end,
      description_draft: description_draft_json(product.description_draft),
      price_research: price_research_json(product.price_research),
      marketplace_listings:
        Enum.map(product.marketplace_listings || [], &marketplace_listing_json/1),
      images: Enum.map(product.images || [], &image_json/1)
    }
  end

  defp product_tab_json(nil), do: nil

  defp product_tab_json(product_tab) do
    %{
      id: product_tab.id,
      name: product_tab.name,
      position: product_tab.position
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
      lifestyle_generation_run_id: image.lifestyle_generation_run_id,
      scene_key: image.scene_key,
      variant_index: image.variant_index,
      source_image_ids: image.source_image_ids || [],
      seller_approved: image.seller_approved,
      approved_at: datetime_to_iso8601(image.approved_at),
      storefront_visible: image.storefront_visible,
      storefront_position: image.storefront_position,
      inserted_at: datetime_to_iso8601(image.inserted_at),
      updated_at: datetime_to_iso8601(image.updated_at)
    }
  end

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp date_to_iso8601(nil), do: nil
  defp date_to_iso8601(%Date{} = date), do: Date.to_iso8601(date)
  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _other -> nil
    end
  end

  defp parse_date(_value), do: nil

  defp normalize_page_size(nil), do: nil
  defp normalize_page_size(""), do: nil

  defp normalize_page_size(value) when is_integer(value) and value > 0 do
    min(value, 100)
  end

  defp normalize_page_size(value) when is_binary(value) do
    case Integer.parse(value) do
      {page_size, ""} when page_size > 0 -> min(page_size, 100)
      _other -> nil
    end
  end

  defp normalize_page_size(_value), do: nil

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
      external_url: listing.external_url,
      external_url_added_at: datetime_to_iso8601(listing.external_url_added_at),
      last_generated_at: datetime_to_iso8601(listing.last_generated_at),
      inserted_at: datetime_to_iso8601(listing.inserted_at),
      updated_at: datetime_to_iso8601(listing.updated_at)
    }
  end

  defp lifestyle_generation_run_json(run) do
    %{
      id: run.id,
      status: run.status,
      step: run.step,
      scene_family: run.scene_family,
      model: run.model,
      prompt_version: run.prompt_version,
      requested_count: run.requested_count,
      completed_count: run.completed_count,
      error_code: run.error_code,
      error_message: run.error_message,
      started_at: datetime_to_iso8601(run.started_at),
      finished_at: datetime_to_iso8601(run.finished_at),
      inserted_at: datetime_to_iso8601(run.inserted_at),
      updated_at: datetime_to_iso8601(run.updated_at),
      payload: run.payload
    }
  end

  defp humanize_config_key(:access_key_id), do: "TIGRIS_ACCESS_KEY_ID"
  defp humanize_config_key(:secret_access_key), do: "TIGRIS_SECRET_ACCESS_KEY"
  defp humanize_config_key(:base_url), do: "TIGRIS_BUCKET_URL"
  defp humanize_config_key(:bucket_name), do: "TIGRIS_BUCKET_NAME"
  defp humanize_config_key(config_key), do: to_string(config_key)

  defp render_limit_exceeded(conn, details) do
    conn
    |> put_status(402)
    |> json(%{
      error: "limit_exceeded",
      operation: details.operation,
      used: details.used,
      limit: details.limit,
      upgrade_url: absolute_pricing_url(details)
    })
  end

  defp absolute_pricing_url(%{upgrade_path: url}) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when is_binary(scheme) and is_binary(host) -> url
      _other -> URI.merge(ResellerWeb.Endpoint.url(), url) |> to_string()
    end
  end

  defp absolute_pricing_url(_details) do
    URI.merge(ResellerWeb.Endpoint.url(), "/pricing") |> to_string()
  end

  defp marketplace_external_url_validation(conn, marketplace, %Ecto.Changeset{} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{
        code: "validation_failed",
        detail: "Validation failed",
        status: 422,
        fields: %{
          "marketplace_external_urls" => %{
            marketplace => errors_for_field(changeset, :external_url)
          }
        }
      }
    })
  end

  defp errors_for_field(%Ecto.Changeset{} = changeset, field) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Map.get(field, ["is invalid"])
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(_value), do: nil
end
