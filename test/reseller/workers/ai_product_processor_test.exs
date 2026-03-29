defmodule Reseller.Workers.AIProductProcessorTest do
  use Reseller.DataCase, async: true

  alias Reseller.Catalog
  alias Reseller.AI
  alias Reseller.Workers
  alias Reseller.Workers.AIProductProcessor

  test "processes uploaded images into a ready product when recognition is confident" do
    user = user_fixture()
    product = finalized_product_fixture(user)

    recognize_result =
      {:ok,
       %{
         provider: :gemini,
         output: %{
           "brand" => "Nike",
           "category" => "Sneakers",
           "possible_model" => "Air Max 90",
           "color" => "White",
           "material" => "Mesh",
           "distinguishing_features" => ["visible air unit", "mesh upper"],
           "confidence_score" => 0.91,
           "needs_review" => false
         }
       }}

    assert {:ok, run} =
             Workers.start_product_processing(product,
               processor: AIProductProcessor,
               public_base_url: "https://cdn.example.com/catalog",
               ai_provider: Reseller.Support.Fakes.AIProvider,
               search_provider: Reseller.Support.Fakes.SearchProvider,
               recognize_result: recognize_result,
               description_result:
                 {:ok,
                  %{
                    provider: :gemini,
                    model: "gemini-description",
                    output: %{
                      "suggested_title" => "Nike Air Max 90",
                      "short_description" => "Classic Nike Air Max 90 sneakers in white mesh.",
                      "long_description" =>
                        "White Nike Air Max 90 sneakers with breathable mesh and a visible air unit.",
                      "key_features" => ["Visible air unit", "Mesh upper"],
                      "seo_keywords" => ["nike air max 90", "white sneakers"]
                    }
                  }},
               shopping_result:
                 {:ok,
                  %{
                    provider: :serp_api,
                    matches: [
                      %{"title" => "Nike Air Max 90", "price" => 129.0, "source" => "GOAT"}
                    ]
                  }},
               price_result:
                 {:ok,
                  %{
                    provider: :gemini,
                    model: "gemini-pricing",
                    output: %{
                      "currency" => "USD",
                      "suggested_min_price" => 110,
                      "suggested_target_price" => 125,
                      "suggested_max_price" => 145,
                      "suggested_median_price" => 126,
                      "pricing_confidence" => 0.82,
                      "rationale_summary" =>
                        "Recent comparable sales center around the mid-120s.",
                      "market_signals" => ["Strong sneaker demand"],
                      "comparable_results" => [
                        %{"title" => "Nike Air Max 90", "price" => 129.0, "source" => "GOAT"}
                      ]
                    }
                  }}
             )

    assert run.status == "completed"
    assert run.step == "price_researched"
    assert run.payload["pipeline_status"] == "recognized"
    assert run.payload["final"]["brand"] == "Nike"
    assert run.payload["description_draft"]["suggested_title"] == "Nike Air Max 90"
    assert run.payload["price_research"]["suggested_target_price"] == "125"

    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert refreshed_product.status == "ready"
    assert refreshed_product.title == "Nike Air Max 90"
    assert refreshed_product.brand == "Nike"
    assert refreshed_product.category == "Sneakers"
    assert refreshed_product.color == "White"
    assert refreshed_product.material == "Mesh"
    assert refreshed_product.ai_summary == "visible air unit, mesh upper"
    assert refreshed_product.ai_confidence == 0.91
    assert refreshed_product.description_draft.suggested_title == "Nike Air Max 90"
    assert refreshed_product.description_draft.short_description =~ "Classic Nike Air Max 90"
    assert refreshed_product.price_research.currency == "USD"

    assert Decimal.to_string(refreshed_product.price_research.suggested_target_price, :normal) ==
             "125.00"

    assert refreshed_product.price_research.rationale_summary =~ "mid-120s"
    assert Enum.all?(refreshed_product.images, &(&1.processing_status == "ready"))

    assert_received {:ai_provider_called, :recognize_images, [image_input], metadata, _opts}
    assert image_input.kind == "original"
    assert image_input.mime_type == "image/jpeg"
    assert image_input.uri =~ "/users/#{user.id}/products/#{product.id}/originals/"
    assert metadata["existing_title"] == nil
    assert_received {:ai_provider_called, :generate_description, description_attrs, _opts}
    assert description_attrs["brand"] == "Nike"
    assert description_attrs["recognition"]["possible_model"] == "Air Max 90"
    assert_received {:search_provider_called, :shopping_matches, shopping_query, _opts}
    assert shopping_query == "Nike Nike Air Max 90 Sneakers"
    assert_received {:ai_provider_called, :research_price, pricing_attrs, search_results, _opts}
    assert pricing_attrs["title"] == "Nike Air Max 90"
    assert length(search_results["shopping_matches"]) == 1

    refute_received {:search_provider_called, :lens_matches, _, _}
  end

  test "keeps the product in review when low-confidence recognition needs reconciliation" do
    user = user_fixture()
    product = finalized_product_fixture(user)

    recognize_result =
      {:ok,
       %{
         provider: :gemini,
         output: %{
           "brand" => "Coach",
           "category" => "Shoulder Bag",
           "color" => "Black",
           "material" => "Leather",
           "confidence_score" => 0.44,
           "needs_review" => true
         }
       }}

    lens_result =
      {:ok,
       %{
         provider: :serp_api,
         matches: [%{"title" => "Coach Tabby 26 Shoulder Bag", "price" => 198.0}]
       }}

    reconcile_result =
      {:ok,
       %{
         provider: :gemini,
         output: %{
           "most_likely_model" => "Tabby 26",
           "same_model_family" => true,
           "short_card_description" => "Coach Tabby 26 shoulder bag",
           "review_notes" => ["verify hardware finish and strap details"]
         }
       }}

    assert {:ok, run} =
             Workers.start_product_processing(product,
               processor: AIProductProcessor,
               public_base_url: "https://cdn.example.com/catalog",
               ai_provider: Reseller.Support.Fakes.AIProvider,
               search_provider: Reseller.Support.Fakes.SearchProvider,
               recognize_result: recognize_result,
               lens_result: lens_result,
               reconcile_result: reconcile_result,
               description_result:
                 {:ok,
                  %{
                    provider: :gemini,
                    model: "gemini-description",
                    output: %{
                      "suggested_title" => "Coach Tabby 26 shoulder bag",
                      "short_description" =>
                        "Black Coach Tabby 26 shoulder bag in leather with review notes.",
                      "long_description" =>
                        "Leather Coach Tabby 26 shoulder bag. Review hardware and strap details before publishing.",
                      "key_features" => ["Leather body", "Shoulder strap"],
                      "seo_keywords" => ["coach tabby 26", "black shoulder bag"],
                      "missing_details_warning" =>
                        "Verify hardware finish and strap details before listing."
                    }
                  }},
               shopping_result:
                 {:ok,
                  %{
                    provider: :serp_api,
                    matches: [
                      %{"title" => "Coach Tabby 26", "price" => 210.0, "source" => "Fashionphile"}
                    ]
                  }},
               price_result:
                 {:ok,
                  %{
                    provider: :gemini,
                    model: "gemini-pricing",
                    output: %{
                      "currency" => "USD",
                      "suggested_min_price" => 180,
                      "suggested_target_price" => 205,
                      "suggested_max_price" => 235,
                      "suggested_median_price" => 208,
                      "pricing_confidence" => 0.58,
                      "rationale_summary" =>
                        "Comparable resale listings vary by hardware and condition.",
                      "market_signals" => ["Luxury bag pricing varies by condition"],
                      "comparable_results" => [
                        %{
                          "title" => "Coach Tabby 26",
                          "price" => 210.0,
                          "source" => "Fashionphile"
                        }
                      ]
                    }
                  }}
             )

    assert run.status == "completed"
    assert run.step == "price_researched"
    assert run.payload["pipeline_status"] == "reconciled"
    assert length(run.payload["search_matches"]) == 1
    assert run.payload["final"]["possible_model"] == "Tabby 26"

    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert refreshed_product.status == "review"
    assert refreshed_product.title == "Coach Tabby 26 shoulder bag"
    assert refreshed_product.brand == "Coach"
    assert refreshed_product.category == "Shoulder Bag"
    assert refreshed_product.ai_summary == "Coach Tabby 26 shoulder bag"
    assert refreshed_product.description_draft.status == "review"
    assert refreshed_product.description_draft.missing_details_warning =~ "Verify hardware finish"
    assert refreshed_product.price_research.status == "review"

    assert Decimal.to_string(refreshed_product.price_research.suggested_median_price, :normal) ==
             "208.00"

    assert Enum.all?(refreshed_product.images, &(&1.processing_status == "ready"))

    assert_received {:search_provider_called, :lens_matches,
                     "https://cdn.example.com/catalog/" <> _, _opts}

    assert_received {:ai_provider_called, :reconcile_product, recognition_output, search_output,
                     _opts}

    assert recognition_output["brand"] == "Coach"
    assert length(search_output.matches) == 1
  end

  test "marks the run, product, and images as failed when public image URLs are unavailable" do
    user = user_fixture()
    product = finalized_product_fixture(user)

    assert {:ok, _run} =
             Workers.start_product_processing(product, processor: AIProductProcessor)

    failed_run = Workers.latest_product_processing_run(product.id)
    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert failed_run.status == "failed"
    assert failed_run.error_code == "media_unavailable"
    assert refreshed_product.status == "review"
    assert Enum.all?(refreshed_product.images, &(&1.processing_status == "failed"))

    refute_received {:ai_provider_called, :recognize_images, _, _, _}
  end

  test "upsert_product_description_draft/2 stores generated copy separately from product fields" do
    user = user_fixture()
    product = product_fixture(user, %{"title" => "User-entered title"})

    assert {:ok, draft} =
             AI.upsert_product_description_draft(product, %{
               provider: :gemini,
               model: "gemini-description",
               output: %{
                 "suggested_title" => "Generated title",
                 "short_description" => "Generated short description",
                 "long_description" => "Generated long description",
                 "key_features" => ["Feature one"],
                 "seo_keywords" => ["keyword-one"]
               }
             })

    assert draft.suggested_title == "Generated title"
    assert draft.short_description == "Generated short description"

    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert refreshed_product.title == "User-entered title"
    assert refreshed_product.description_draft.id == draft.id
    assert refreshed_product.description_draft.suggested_title == "Generated title"
  end

  test "upsert_product_price_research/2 stores generated pricing separately from product fields" do
    user = user_fixture()
    product = product_fixture(user, %{"price" => Decimal.new("300.00")})

    assert {:ok, price_research} =
             AI.upsert_product_price_research(product, %{
               provider: :gemini,
               model: "gemini-pricing",
               output: %{
                 "currency" => "USD",
                 "suggested_min_price" => 110,
                 "suggested_target_price" => 125,
                 "suggested_max_price" => 145,
                 "suggested_median_price" => 126,
                 "pricing_confidence" => 0.81,
                 "rationale_summary" => "Comparable sales support a mid-range price.",
                 "market_signals" => ["Steady demand"],
                 "comparable_results" => [%{"title" => "Comparable item", "price" => 129.0}]
               }
             })

    assert price_research.currency == "USD"
    assert Decimal.equal?(price_research.suggested_target_price, Decimal.new("125"))

    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert Decimal.to_string(refreshed_product.price, :normal) == "300.00"
    assert refreshed_product.price_research.id == price_research.id

    assert Decimal.to_string(refreshed_product.price_research.suggested_median_price, :normal) ==
             "126.00"
  end

  defp finalized_product_fixture(user) do
    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{},
        [%{"filename" => "item-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    {:ok, %{product: finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    finalized_product
  end
end
