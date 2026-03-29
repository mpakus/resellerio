defmodule Reseller.Workers.AIProductProcessor do
  @moduledoc """
  Runs the recognition pipeline against finalized product images and persists the
  normalized result back onto the product record.
  """

  @behaviour Reseller.Workers.ProductProcessor

  alias Reseller.AI
  alias Reseller.Catalog
  alias Reseller.Catalog.Product
  alias Reseller.Media

  @impl true
  def process(%Product{} = product, opts) do
    with {:ok, images} <- Media.recognition_inputs_for_product(product, opts),
         {:ok, result} <- AI.run_recognition_pipeline(images, recognition_metadata(product), opts),
         {:ok, updated_product} <- Catalog.apply_recognition_result(product, result.final),
         {:ok, description_result} <-
           AI.generate_description(description_input(updated_product, result.final), opts),
         {:ok, description_draft} <-
           AI.upsert_product_description_draft(updated_product, description_result),
         {:ok, _updated_count} <- Media.mark_product_images_ready(updated_product) do
      {:ok,
       %{
         step: "description_generated",
         payload: build_payload(updated_product, result, description_draft)
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

  defp build_payload(%Product{} = product, result, description_draft) do
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

  defp format_error(reason) do
    %{
      code: "processor_error",
      message: "AI product processing failed: #{inspect(reason)}",
      payload: %{"reason" => inspect(reason)}
    }
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
end
