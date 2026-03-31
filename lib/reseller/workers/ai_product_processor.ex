defmodule Reseller.Workers.AIProductProcessor do
  @moduledoc """
  Runs the recognition pipeline against finalized product images and persists the
  normalized result back onto the product record.
  """

  @behaviour Reseller.Workers.ProductProcessor

  alias Reseller.AI
  alias Reseller.Catalog
  alias Reseller.Catalog.Product
  alias Reseller.Marketplaces
  alias Reseller.Media
  alias Reseller.Repo
  alias Reseller.Search
  alias Reseller.Workers.LifestyleImageGenerator

  @impl true
  def process(%Product{} = product, opts) do
    with {:ok, images} <- Media.recognition_inputs_for_product(product, opts),
         {:ok, result} <-
           AI.run_recognition_pipeline(images, recognition_metadata(product), opts),
         {:ok, updated_product} <- Catalog.apply_recognition_result(product, result.final),
         {:ok, description_result} <-
           AI.generate_description(description_input(updated_product, result.final), opts),
         {:ok, description_draft} <-
           AI.upsert_product_description_draft(updated_product, description_result),
         {:ok, search_results} <- price_search_results(updated_product, result, opts),
         {:ok, price_result} <-
           AI.research_price(price_input(updated_product, result.final), search_results, opts),
         {:ok, price_research} <- AI.upsert_product_price_research(updated_product, price_result),
         {:ok, marketplace_listings} <-
           generate_marketplace_listings(
             updated_product,
             result.final,
             description_draft,
             price_research,
             opts
           ),
         variant_generation = generate_image_variants(updated_product, opts),
         {:ok, _updated_count} <- Media.mark_product_images_ready(updated_product) do
      ready_product = Repo.preload(updated_product, :images, force: true)
      lifestyle_generation = generate_lifestyle_images(ready_product, opts)

      {:ok,
       %{
         step: processing_step(variant_generation, lifestyle_generation),
         payload:
           build_payload(
             ready_product,
             result,
             description_draft,
             price_research,
             marketplace_listings,
             variant_generation,
             lifestyle_generation
           )
       }}
    else
      {:error, reason} -> {:error, format_error(reason)}
    end
  end

  defp recognition_metadata(%Product{} = product) do
    %{
      "product_id" => product.id,
      "existing_title" => product.title,
      "existing_brand" => product.brand,
      "existing_category" => product.category,
      "existing_color" => product.color,
      "existing_material" => product.material
    }
  end

  defp description_input(%Product{} = product, final_result) do
    %{
      "product_id" => product.id,
      "title" => product.title,
      "brand" => product.brand,
      "category" => product.category,
      "condition" => product.condition,
      "color" => product.color,
      "size" => product.size,
      "material" => product.material,
      "ai_summary" => product.ai_summary,
      "recognition" => final_result
    }
  end

  defp price_input(%Product{} = product, final_result) do
    %{
      "product_id" => product.id,
      "title" => product.title,
      "brand" => product.brand,
      "category" => product.category,
      "condition" => product.condition,
      "color" => product.color,
      "size" => product.size,
      "material" => product.material,
      "ai_summary" => product.ai_summary,
      "recognition" => final_result
    }
  end

  defp build_payload(
         %Product{} = product,
         result,
         description_draft,
         price_research,
         marketplace_listings,
         variant_generation,
         lifestyle_generation
       ) do
    %{
      "pipeline_status" => Atom.to_string(result.status),
      "selected_image_count" => length(result.selected_images),
      "review_required" => Map.get(result.final, "needs_review", false),
      "final" => result.final,
      "fallback" => stringify_map(result.fallback || %{}),
      "search_matches" => search_matches(result.search),
      "description_draft" => %{
        "id" => description_draft.id,
        "status" => description_draft.status,
        "suggested_title" => description_draft.suggested_title,
        "short_description" => description_draft.short_description
      },
      "price_research" => %{
        "id" => price_research.id,
        "status" => price_research.status,
        "currency" => price_research.currency,
        "suggested_target_price" => decimal_to_string(price_research.suggested_target_price),
        "suggested_median_price" => decimal_to_string(price_research.suggested_median_price),
        "pricing_confidence" => price_research.pricing_confidence
      },
      "marketplace_listings" => Enum.map(marketplace_listings, &marketplace_listing_payload/1),
      "variant_generation" => variant_generation,
      "lifestyle_generation" => lifestyle_generation,
      "product" => %{
        "id" => product.id,
        "status" => product.status,
        "title" => product.title,
        "brand" => product.brand,
        "category" => product.category,
        "color" => product.color,
        "material" => product.material,
        "ai_confidence" => product.ai_confidence
      }
    }
  end

  defp generate_image_variants(%Product{} = product, opts) do
    case Media.generate_product_variants(product, opts) do
      {:ok, variants} ->
        %{
          "status" => "generated",
          "count" => length(variants),
          "variants" => Enum.map(variants, &variant_payload/1)
        }

      {:error, reason} ->
        %{
          "status" => "failed",
          "count" => 0,
          "error" => humanize_variant_generation_error(reason),
          "error_reason" => inspect(reason),
          "variants" => []
        }
    end
  end

  defp variant_generation_step(%{"status" => "generated"}), do: "variants_generated"
  defp variant_generation_step(_variant_generation), do: "variants_failed"

  defp processing_step(_variant_generation, %{"status" => "generated"}), do: "lifestyle_generated"
  defp processing_step(_variant_generation, %{"status" => "partial"}), do: "lifestyle_partial"
  defp processing_step(_variant_generation, %{"status" => "failed"}), do: "lifestyle_failed"

  defp processing_step(variant_generation, _lifestyle_generation),
    do: variant_generation_step(variant_generation)

  defp generate_lifestyle_images(%Product{} = product, opts) do
    LifestyleImageGenerator.generate(product, opts)
  end

  defp generate_marketplace_listings(
         %Product{} = product,
         final_result,
         description_draft,
         price_research,
         opts
       ) do
    marketplaces = Marketplaces.selected_marketplaces(opts)

    marketplaces
    |> Enum.reduce_while({:ok, []}, fn marketplace, {:ok, listings} ->
      attrs =
        marketplace_listing_input(
          product,
          marketplace,
          final_result,
          description_draft,
          price_research
        )

      with {:ok, listing_result} <- AI.generate_marketplace_listing(attrs, opts),
           {:ok, listing} <-
             Marketplaces.upsert_marketplace_listing(product, marketplace, listing_result) do
        {:cont, {:ok, listings ++ [listing]}}
      else
        {:error, reason} -> {:halt, {:error, {:marketplace_listing_failed, marketplace, reason}}}
      end
    end)
  end

  defp marketplace_listing_input(
         %Product{} = product,
         marketplace,
         final_result,
         description_draft,
         price_research
       ) do
    %{
      "marketplace" => marketplace,
      "product" => %{
        "id" => product.id,
        "title" => product.title,
        "brand" => product.brand,
        "category" => product.category,
        "condition" => product.condition,
        "color" => product.color,
        "size" => product.size,
        "material" => product.material,
        "ai_summary" => product.ai_summary,
        "recognition" => final_result
      },
      "description_draft" => %{
        "suggested_title" => description_draft.suggested_title,
        "short_description" => description_draft.short_description,
        "long_description" => description_draft.long_description,
        "key_features" => description_draft.key_features,
        "seo_keywords" => description_draft.seo_keywords,
        "missing_details_warning" => description_draft.missing_details_warning
      },
      "price_research" => %{
        "currency" => price_research.currency,
        "suggested_min_price" => decimal_to_string(price_research.suggested_min_price),
        "suggested_target_price" => decimal_to_string(price_research.suggested_target_price),
        "suggested_max_price" => decimal_to_string(price_research.suggested_max_price),
        "suggested_median_price" => decimal_to_string(price_research.suggested_median_price),
        "pricing_confidence" => price_research.pricing_confidence,
        "rationale_summary" => price_research.rationale_summary,
        "market_signals" => price_research.market_signals
      }
    }
  end

  defp price_search_results(%Product{} = product, result, opts) do
    shopping_query = price_query(product, result.final)

    with {:ok, shopping_matches} <- maybe_fetch_shopping_matches(shopping_query, opts) do
      {:ok,
       %{
         "lens_matches" => search_matches(result.search),
         "shopping_matches" => shopping_matches,
         "shopping_query" => shopping_query
       }}
    end
  end

  defp price_query(%Product{} = product, final_result) do
    [
      product.brand || final_result["brand"],
      product.title,
      product.category || final_result["category"]
    ]
    |> Enum.filter(&present?/1)
    |> Enum.uniq()
    |> Enum.join(" ")
  end

  defp maybe_fetch_shopping_matches("", _opts), do: {:ok, []}

  defp maybe_fetch_shopping_matches(query, opts) do
    case Search.shopping_matches(query, search_opts(opts)) do
      {:ok, %{matches: matches}} when is_list(matches) ->
        {:ok, Enum.map(matches, &stringify_map/1)}

      {:ok, %{"matches" => matches}} when is_list(matches) ->
        {:ok, Enum.map(matches, &stringify_map/1)}

      {:ok, _result} ->
        {:ok, []}

      {:error, reason} ->
        {:error, {:shopping_search_failed, reason}}
    end
  end

  defp search_matches(nil), do: []

  defp search_matches(%{matches: matches}) when is_list(matches),
    do: Enum.map(matches, &stringify_map/1)

  defp search_matches(%{"matches" => matches}) when is_list(matches),
    do: Enum.map(matches, &stringify_map/1)

  defp search_matches(_search_result), do: []

  defp format_error(:missing_public_base_url) do
    %{
      code: "media_unavailable",
      message: "Public image URL base is not configured",
      payload: %{}
    }
  end

  defp format_error(:invalid_public_base_url) do
    %{
      code: "media_unavailable",
      message: "Configured public image URL base is invalid",
      payload: %{}
    }
  end

  defp format_error(:no_recognition_images) do
    %{
      code: "no_recognition_images",
      message: "No uploaded images are available for AI recognition",
      payload: %{}
    }
  end

  defp format_error({:image_download_failed, {:http_error, status, body}}) do
    %{
      code: "media_unavailable",
      message:
        "The worker could not download the product image bytes for Gemini (HTTP #{status}). Check storage access and retry processing.",
      payload: %{
        "provider" => "storage",
        "status" => Integer.to_string(status),
        "retryable" => true,
        "reason" => inspect({:image_download_failed, {:http_error, status, body}})
      }
    }
  end

  defp format_error(
         {:image_download_failed, {:request_failed, %Req.TransportError{reason: reason}}}
       )
       when reason in [:timeout, :connect_timeout, :closed] do
    %{
      code: "media_unavailable",
      message:
        "The worker timed out while downloading the product image bytes for Gemini. Retry processing.",
      payload: %{
        "provider" => "storage",
        "transport_reason" => to_string(reason),
        "retryable" => true,
        "reason" =>
          inspect(
            {:image_download_failed, {:request_failed, %Req.TransportError{reason: reason}}}
          )
      }
    }
  end

  defp format_error({:image_download_failed, reason}) do
    %{
      code: "media_unavailable",
      message:
        "The worker could not download the product image bytes for Gemini. Check storage access and retry processing.",
      payload: %{
        "provider" => "storage",
        "retryable" => true,
        "reason" => inspect({:image_download_failed, reason})
      }
    }
  end

  defp format_error({:shopping_search_failed, reason}) do
    %{
      code: "shopping_search_failed",
      message: "External shopping search failed: #{inspect(reason)}",
      payload: %{"reason" => inspect(reason)}
    }
  end

  defp format_error({:marketplace_listing_failed, marketplace, reason}) do
    %{
      code: "marketplace_listing_failed",
      message: "Marketplace listing generation failed for #{marketplace}: #{inspect(reason)}",
      payload: %{"marketplace" => marketplace, "reason" => inspect(reason)}
    }
  end

  defp format_error({:http_error, 429, %{"error" => error} = body}) when is_map(error) do
    detail = Map.get(error, "message") || "The AI provider rejected the request."
    provider_status = Map.get(error, "status")

    cond do
      provider_status == "RESOURCE_EXHAUSTED" ->
        %{
          code: "ai_quota_exhausted",
          message:
            "Gemini quota is exhausted right now. Wait for quota to recover or raise the Gemini limit, then retry processing.",
          payload: %{
            "provider" => "gemini",
            "status" => provider_status,
            "detail" => detail,
            "retryable" => true,
            "reason" => inspect({:http_error, 429, body})
          }
        }

      true ->
        %{
          code: "ai_rate_limited",
          message: "Gemini rate-limited the request. Try processing again in a moment.",
          payload: %{
            "provider" => "gemini",
            "status" => provider_status,
            "detail" => detail,
            "retryable" => true,
            "reason" => inspect({:http_error, 429, body})
          }
        }
    end
  end

  defp format_error({:http_error, 429, body}) do
    %{
      code: "ai_rate_limited",
      message: "Gemini rate-limited the request. Try processing again in a moment.",
      payload: %{
        "provider" => "gemini",
        "retryable" => true,
        "reason" => inspect({:http_error, 429, body})
      }
    }
  end

  defp format_error({:http_error, 400, %{"error" => error} = body}) when is_map(error) do
    detail = Map.get(error, "message") || "The AI provider rejected the request."

    cond do
      String.contains?(detail, "Cannot fetch content from the provided URL") ->
        %{
          code: "ai_media_fetch_failed",
          message:
            "Gemini could not fetch the product image URL. Check storage download signing or public object access and retry processing.",
          payload: %{
            "provider" => "gemini",
            "status" => Map.get(error, "status"),
            "detail" => detail,
            "retryable" => true,
            "reason" => inspect({:http_error, 400, body})
          }
        }

      String.contains?(detail, "Tool use with a response mime type") ->
        %{
          code: "ai_grounding_request_invalid",
          message:
            "Gemini rejected the grounded price request format. The provider request shape needs to be adjusted before retrying.",
          payload: %{
            "provider" => "gemini",
            "status" => Map.get(error, "status"),
            "detail" => detail,
            "retryable" => false,
            "reason" => inspect({:http_error, 400, body})
          }
        }

      true ->
        %{
          code: "processor_error",
          message: "AI product processing failed: #{inspect({:http_error, 400, body})}",
          payload: %{"reason" => inspect({:http_error, 400, body})}
        }
    end
  end

  defp format_error({:request_failed, %Req.TransportError{reason: reason}})
       when reason in [:timeout, :connect_timeout, :closed] do
    %{
      code: "ai_provider_timeout",
      message:
        "Gemini timed out while processing this product. The run can be retried without uploading images again.",
      payload: %{
        "provider" => "gemini",
        "transport_reason" => to_string(reason),
        "retryable" => true,
        "reason" => inspect({:request_failed, %Req.TransportError{reason: reason}})
      }
    }
  end

  defp format_error(reason) do
    %{
      code: "processor_error",
      message: "AI product processing failed: #{inspect(reason)}",
      payload: %{"reason" => inspect(reason)}
    }
  end

  defp search_opts(opts) do
    opts
    |> Keyword.take([:request_fun, :config, :query, :hl, :gl, :shopping_result, :lens_result])
    |> Keyword.put_new(:provider, Keyword.get(opts, :search_provider, Search.provider()))
  end

  defp stringify_map(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) -> {to_string(key), stringify_map(value)}
      {key, value} when is_list(value) -> {to_string(key), Enum.map(value, &stringify_value/1)}
      {key, value} -> {to_string(key), value}
    end)
  end

  defp stringify_value(value) when is_map(value), do: stringify_map(value)
  defp stringify_value(value), do: value

  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)

  defp marketplace_listing_payload(listing) do
    %{
      "id" => listing.id,
      "marketplace" => listing.marketplace,
      "status" => listing.status,
      "generated_title" => listing.generated_title,
      "generated_price_suggestion" => decimal_to_string(listing.generated_price_suggestion)
    }
  end

  defp variant_payload(image) do
    %{
      "id" => image.id,
      "kind" => image.kind,
      "position" => image.position,
      "background_style" => image.background_style,
      "processing_status" => image.processing_status
    }
  end

  defp humanize_variant_generation_error({:variant_generation_failed, _kind, :missing_api_key}) do
    "Photoroom API key is missing. Add PHOTOROOM_API_KEY and retry processing."
  end

  defp humanize_variant_generation_error(
         {:variant_generation_failed, kind, {:http_error, status, _body}}
       ) do
    "Photoroom failed while generating #{humanize_kind(kind)} (HTTP #{status})."
  end

  defp humanize_variant_generation_error(
         {:variant_generation_failed, kind,
          {:request_failed, %Req.TransportError{reason: reason}}}
       ) do
    "Photoroom timed out while generating #{humanize_kind(kind)} (#{reason})."
  end

  defp humanize_variant_generation_error({:variant_generation_failed, kind, reason}) do
    "Photoroom failed while generating #{humanize_kind(kind)}: #{inspect(reason)}"
  end

  defp humanize_variant_generation_error(reason), do: inspect(reason)

  defp humanize_kind(kind) when is_binary(kind) do
    kind
    |> String.replace("_", " ")
    |> Phoenix.Naming.humanize()
  end

  defp humanize_kind(_kind), do: "variant"

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
