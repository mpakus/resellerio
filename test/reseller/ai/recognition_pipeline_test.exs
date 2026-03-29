defmodule Reseller.AI.RecognitionPipelineTest do
  use ExUnit.Case, async: true

  alias Reseller.AI

  test "returns a recognition-only result when confidence is high" do
    images = [
      %{
        kind: "original",
        mime_type: "image/jpeg",
        uri: "https://cdn.example.com/item-1.jpg",
        external_url: "https://cdn.example.com/item-1.jpg"
      }
    ]

    recognize_result =
      {:ok,
       %{
         provider: :gemini,
         output: %{
           "brand" => "Nike",
           "possible_model" => "Air Max 90",
           "confidence_score" => 0.92,
           "needs_review" => false
         }
       }}

    assert {:ok, result} =
             AI.run_recognition_pipeline(
               images,
               %{"brand_hint" => "Nike"},
               ai_provider: Reseller.Support.Fakes.AIProvider,
               search_provider: Reseller.Support.Fakes.SearchProvider,
               recognize_result: recognize_result
             )

    assert result.status == :recognized
    assert result.search == nil
    assert result.reconciliation == nil
    assert result.final["brand"] == "Nike"
    assert result.final["needs_review"] == false

    assert_received {:ai_provider_called, :recognize_images, ^images, %{"brand_hint" => "Nike"},
                     _opts}

    refute_received {:search_provider_called, :lens_matches, _, _}
  end

  test "uses Lens and reconciliation when recognition confidence is low" do
    images = [
      %{
        kind: "white_background",
        mime_type: "image/jpeg",
        uri: "https://cdn.example.com/item-2-white.jpg",
        external_url: "https://cdn.example.com/item-2-white.jpg"
      },
      %{
        kind: "original",
        mime_type: "image/jpeg",
        uri: "https://cdn.example.com/item-2-original.jpg",
        external_url: "https://cdn.example.com/item-2-original.jpg"
      }
    ]

    recognize_result =
      {:ok,
       %{
         provider: :gemini,
         output: %{
           "brand" => "Nike",
           "confidence_score" => 0.42,
           "needs_review" => true
         }
       }}

    lens_result =
      {:ok,
       %{
         provider: :serp_api,
         matches: [%{"title" => "Nike Air Max 90", "price" => 120.0}]
       }}

    reconcile_result =
      {:ok,
       %{
         provider: :gemini,
         output: %{
           "most_likely_model" => "Air Max 90",
           "same_model_family" => true,
           "short_card_description" => "Nike Air Max 90 sneakers",
           "review_notes" => []
         }
       }}

    assert {:ok, result} =
             AI.run_recognition_pipeline(
               images,
               %{},
               ai_provider: Reseller.Support.Fakes.AIProvider,
               search_provider: Reseller.Support.Fakes.SearchProvider,
               recognize_result: recognize_result,
               lens_result: lens_result,
               reconcile_result: reconcile_result
             )

    assert result.status == :reconciled
    assert result.search == elem(lens_result, 1)
    assert result.reconciliation == elem(reconcile_result, 1)
    assert result.final["possible_model"] == "Air Max 90"
    assert result.final["short_card_description"] == "Nike Air Max 90 sneakers"
    assert result.final["external_match_count"] == 1

    assert_received {:search_provider_called, :lens_matches,
                     "https://cdn.example.com/item-2-white.jpg", _opts}

    assert_received {:ai_provider_called, :reconcile_product, recognition_output, search_output,
                     _opts}

    assert recognition_output["brand"] == "Nike"
    assert search_output.matches == [%{"title" => "Nike Air Max 90", "price" => 120.0}]
  end

  test "keeps the recognition result when Lens fallback fails" do
    images = [
      %{
        kind: "original",
        mime_type: "image/jpeg",
        uri: "https://cdn.example.com/item-3.jpg",
        external_url: "https://cdn.example.com/item-3.jpg"
      }
    ]

    recognize_result =
      {:ok,
       %{
         provider: :gemini,
         output: %{
           "brand" => "Adidas",
           "confidence_score" => 0.3,
           "needs_review" => true
         }
       }}

    assert {:ok, result} =
             AI.run_recognition_pipeline(
               images,
               %{},
               ai_provider: Reseller.Support.Fakes.AIProvider,
               search_provider: Reseller.Support.Fakes.SearchProvider,
               recognize_result: recognize_result,
               lens_result: {:error, :rate_limited}
             )

    assert result.status == :recognized
    assert result.search == nil
    assert result.reconciliation == nil
    assert result.fallback == %{attempted: true, error: :rate_limited}
    assert result.final["brand"] == "Adidas"
    assert result.final["needs_review"]
  end

  test "returns an error when there are no usable images" do
    assert {:error, :no_recognition_images} =
             AI.run_recognition_pipeline([
               %{kind: "original", mime_type: "image/jpeg"},
               %{kind: "normalized", uri: "https://cdn.example.com/no-mime.jpg"}
             ])
  end
end
