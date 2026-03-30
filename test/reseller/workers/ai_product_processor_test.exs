defmodule Reseller.Workers.AIProductProcessorTest do
  use Reseller.DataCase, async: true

  alias Reseller.Catalog
  alias Reseller.AI
  alias Reseller.Marketplaces
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
               media_processor: Reseller.Support.Fakes.MediaProcessor,
               storage: Reseller.Support.Fakes.MediaStorage,
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
                  }},
               marketplace_listing_results: %{
                 "ebay" =>
                   {:ok,
                    %{
                      provider: :gemini,
                      model: "gemini-marketplace",
                      output: %{
                        "generated_title" => "Nike Air Max 90 Sneakers White Mesh",
                        "generated_description" => "eBay-ready sneaker listing copy.",
                        "generated_tags" => ["nike", "air max 90", "sneakers"],
                        "generated_price_suggestion" => 129,
                        "generation_version" => "gemini-marketplace-v1",
                        "compliance_warnings" => []
                      }
                    }},
                 "depop" =>
                   {:ok,
                    %{
                      provider: :gemini,
                      model: "gemini-marketplace",
                      output: %{
                        "generated_title" => "Nike Air Max 90 white mesh runners",
                        "generated_description" => "Depop-ready sneaker listing copy.",
                        "generated_tags" => ["nike", "runners", "streetwear"],
                        "generated_price_suggestion" => 127,
                        "generation_version" => "gemini-marketplace-v1",
                        "compliance_warnings" => []
                      }
                    }},
                 "poshmark" =>
                   {:ok,
                    %{
                      provider: :gemini,
                      model: "gemini-marketplace",
                      output: %{
                        "generated_title" => "Nike Air Max 90 athletic sneakers",
                        "generated_description" => "Poshmark-ready sneaker listing copy.",
                        "generated_tags" => ["nike", "athleisure", "sneakers"],
                        "generated_price_suggestion" => 130,
                        "generation_version" => "gemini-marketplace-v1",
                        "compliance_warnings" => []
                      }
                    }}
               }
             )

    assert run.status == "completed"
    assert run.step == "variants_generated"
    assert run.payload["pipeline_status"] == "recognized"
    assert run.payload["final"]["brand"] == "Nike"
    assert run.payload["description_draft"]["suggested_title"] == "Nike Air Max 90"
    assert run.payload["price_research"]["suggested_target_price"] == "125"

    assert Enum.map(run.payload["marketplace_listings"], & &1["marketplace"]) == [
             "ebay",
             "depop",
             "poshmark"
           ]

    assert run.payload["variant_generation"]["status"] == "generated"
    assert run.payload["variant_generation"]["count"] == 2

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

    assert Enum.map(refreshed_product.marketplace_listings, & &1.marketplace) == [
             "depop",
             "ebay",
             "poshmark"
           ]

    assert Enum.map(refreshed_product.images, & &1.kind) == [
             "original",
             "background_removed",
             "white_background"
           ]

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

    assert_received {:ai_provider_called, :generate_marketplace_listing,
                     %{"marketplace" => "ebay"}, _opts}

    assert_received {:ai_provider_called, :generate_marketplace_listing,
                     %{"marketplace" => "depop"}, _opts}

    assert_received {:ai_provider_called, :generate_marketplace_listing,
                     %{"marketplace" => "poshmark"}, _opts}

    assert_received {:media_processor_called, "https://cdn.example.com/catalog/" <> _,
                     %{kind: "background_removed"}, _opts}

    assert_received {:media_processor_called, "https://cdn.example.com/catalog/" <> _,
                     %{kind: "white_background"}, _opts}

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
               media_processor: Reseller.Support.Fakes.MediaProcessor,
               storage: Reseller.Support.Fakes.MediaStorage,
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
                  }},
               marketplace_listing_results: %{
                 "ebay" =>
                   {:ok,
                    %{
                      provider: :gemini,
                      model: "gemini-marketplace",
                      output: %{
                        "generated_title" => "Coach Tabby 26 leather bag",
                        "generated_description" => "eBay luxury bag listing copy.",
                        "generated_tags" => ["coach", "tabby", "leather"],
                        "generated_price_suggestion" => 209,
                        "generation_version" => "gemini-marketplace-v1",
                        "compliance_warnings" => []
                      }
                    }},
                 "depop" =>
                   {:ok,
                    %{
                      provider: :gemini,
                      model: "gemini-marketplace",
                      output: %{
                        "generated_title" => "Coach Tabby 26 black shoulder bag",
                        "generated_description" => "Depop bag listing copy with review needed.",
                        "generated_tags" => ["coach", "bag", "minimal"],
                        "generated_price_suggestion" => 205,
                        "generation_version" => "gemini-marketplace-v1",
                        "compliance_warnings" => ["Verify hardware finish before publishing."]
                      }
                    }},
                 "poshmark" =>
                   {:ok,
                    %{
                      provider: :gemini,
                      model: "gemini-marketplace",
                      output: %{
                        "generated_title" => "Coach Tabby 26 shoulder bag",
                        "generated_description" => "Poshmark luxury bag listing copy.",
                        "generated_tags" => ["coach", "luxury", "tabby"],
                        "generated_price_suggestion" => 210,
                        "generation_version" => "gemini-marketplace-v1",
                        "compliance_warnings" => []
                      }
                    }}
               }
             )

    assert run.status == "completed"
    assert run.step == "variants_generated"
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

    assert Enum.any?(refreshed_product.marketplace_listings, fn listing ->
             listing.marketplace == "depop" and listing.status == "review"
           end)

    assert Enum.map(refreshed_product.images, & &1.kind) == [
             "original",
             "background_removed",
             "white_background"
           ]

    assert Enum.all?(refreshed_product.images, &(&1.processing_status == "ready"))

    assert_received {:search_provider_called, :lens_matches,
                     "https://cdn.example.com/catalog/" <> _, _opts}

    assert_received {:ai_provider_called, :reconcile_product, recognition_output, search_output,
                     _opts}

    assert recognition_output["brand"] == "Coach"
    assert length(search_output.matches) == 1
  end

  test "keeps the product usable when variant generation fails" do
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
               media_processor: Reseller.Support.Fakes.MediaProcessor,
               storage: Reseller.Support.Fakes.MediaStorage,
               recognize_result: recognize_result,
               description_result:
                 {:ok,
                  %{
                    provider: :gemini,
                    model: "gemini-description",
                    output: %{
                      "suggested_title" => "Nike Air Max 90",
                      "short_description" => "Short copy"
                    }
                  }},
               shopping_result: {:ok, %{provider: :serp_api, matches: []}},
               price_result:
                 {:ok,
                  %{
                    provider: :gemini,
                    model: "gemini-pricing",
                    output: %{
                      "currency" => "USD",
                      "suggested_target_price" => 125,
                      "pricing_confidence" => 0.8
                    }
                  }},
               marketplace_listing_results: %{
                 "ebay" =>
                   {:ok,
                    %{
                      provider: :gemini,
                      model: "gemini-marketplace",
                      output: %{
                        "generated_title" => "eBay title",
                        "generated_description" => "desc",
                        "generated_price_suggestion" => 125
                      }
                    }},
                 "depop" =>
                   {:ok,
                    %{
                      provider: :gemini,
                      model: "gemini-marketplace",
                      output: %{
                        "generated_title" => "Depop title",
                        "generated_description" => "desc",
                        "generated_price_suggestion" => 124
                      }
                    }},
                 "poshmark" =>
                   {:ok,
                    %{
                      provider: :gemini,
                      model: "gemini-marketplace",
                      output: %{
                        "generated_title" => "Poshmark title",
                        "generated_description" => "desc",
                        "generated_price_suggestion" => 126
                      }
                    }}
               },
               variant_results: %{
                 "background_removed" => {:error, :photoroom_rate_limited}
               }
             )

    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert run.status == "completed"
    assert run.step == "variants_failed"
    assert run.payload["variant_generation"]["status"] == "failed"
    assert refreshed_product.status == "ready"
    assert Enum.map(refreshed_product.images, & &1.kind) == ["original"]
    assert Enum.all?(refreshed_product.images, &(&1.processing_status == "ready"))
  end

  test "marks the run, product, and images as failed when public image URLs are invalid" do
    user = user_fixture()
    product = finalized_product_fixture(user)

    assert {:ok, _run} =
             Workers.start_product_processing(
               product,
               processor: AIProductProcessor,
               storage: Reseller.Support.Fakes.MediaStorage,
               sign_download_result: {:error, :download_signing_failed},
               public_base_url: "not-a-valid-url"
             )

    failed_run = Workers.latest_product_processing_run(product.id)
    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert failed_run.status == "failed"
    assert failed_run.error_code == "media_unavailable"
    assert refreshed_product.status == "review"
    assert Enum.all?(refreshed_product.images, &(&1.processing_status == "failed"))

    refute_received {:ai_provider_called, :recognize_images, _, _, _}
  end

  test "classifies Gemini media fetch failures as retryable storage-url issues" do
    user = user_fixture()
    product = finalized_product_fixture(user)

    assert {:ok, _run} =
             Workers.start_product_processing(
               product,
               processor: AIProductProcessor,
               ai_provider: Reseller.Support.Fakes.AIProvider,
               storage: Reseller.Support.Fakes.MediaStorage,
               recognize_result:
                 {:error,
                  {:http_error, 400,
                   %{
                     "error" => %{
                       "status" => "INVALID_ARGUMENT",
                       "message" => "Cannot fetch content from the provided URL."
                     }
                   }}}
             )

    failed_run = Workers.latest_product_processing_run(product.id)
    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert failed_run.error_code == "ai_media_fetch_failed"
    assert failed_run.error_message =~ "Gemini could not fetch the product image URL"
    assert failed_run.payload["retryable"] == true
    assert refreshed_product.status == "review"
    assert Enum.all?(refreshed_product.images, &(&1.processing_status == "uploaded"))
  end

  test "classifies grounded JSON/tool incompatibility errors explicitly" do
    user = user_fixture()
    product = finalized_product_fixture(user)

    assert {:ok, _run} =
             Workers.start_product_processing(
               product,
               processor: AIProductProcessor,
               ai_provider: Reseller.Support.Fakes.AIProvider,
               recognize_result:
                 {:error,
                  {:http_error, 400,
                   %{
                     "error" => %{
                       "status" => "INVALID_ARGUMENT",
                       "message" =>
                         "Tool use with a response mime type: 'application/json' is unsupported"
                     }
                   }}}
             )

    failed_run = Workers.latest_product_processing_run(product.id)

    assert failed_run.error_code == "ai_grounding_request_invalid"

    assert failed_run.error_message =~
             "Gemini rejected the grounded price request format"

    assert failed_run.payload["retryable"] == false
  end

  test "classifies Gemini quota exhaustion as a retryable AI failure" do
    user = user_fixture()
    product = finalized_product_fixture(user)

    assert {:ok, _run} =
             Workers.start_product_processing(
               product,
               processor: AIProductProcessor,
               public_base_url: "https://cdn.example.com/catalog",
               ai_provider: Reseller.Support.Fakes.AIProvider,
               recognize_result:
                 {:error,
                  {:http_error, 429,
                   %{
                     "error" => %{
                       "status" => "RESOURCE_EXHAUSTED",
                       "message" => "Resource has been exhausted (e.g. check quota)."
                     }
                   }}}
             )

    failed_run = Workers.latest_product_processing_run(product.id)
    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert failed_run.status == "failed"
    assert failed_run.error_code == "ai_quota_exhausted"
    assert failed_run.error_message =~ "Gemini quota is exhausted"
    assert failed_run.payload["retryable"] == true
    assert failed_run.payload["provider"] == "gemini"
    assert failed_run.payload["status"] == "RESOURCE_EXHAUSTED"
    assert refreshed_product.status == "review"
    assert Enum.all?(refreshed_product.images, &(&1.processing_status == "uploaded"))
  end

  test "classifies Gemini request timeouts as retryable AI failures" do
    user = user_fixture()
    product = finalized_product_fixture(user)

    assert {:ok, _run} =
             Workers.start_product_processing(
               product,
               processor: AIProductProcessor,
               ai_provider: Reseller.Support.Fakes.AIProvider,
               recognize_result:
                 {:error, {:request_failed, %Req.TransportError{reason: :timeout}}}
             )

    failed_run = Workers.latest_product_processing_run(product.id)
    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert failed_run.status == "failed"
    assert failed_run.error_code == "ai_provider_timeout"
    assert failed_run.error_message =~ "Gemini timed out while processing this product"
    assert failed_run.payload["retryable"] == true
    assert failed_run.payload["transport_reason"] == "timeout"
    assert refreshed_product.status == "review"
    assert Enum.all?(refreshed_product.images, &(&1.processing_status == "uploaded"))
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

  test "upsert_marketplace_listing/3 stores marketplace copy separately from product fields" do
    user = user_fixture()
    product = product_fixture(user, %{"title" => "User title"})

    assert {:ok, listing} =
             Marketplaces.upsert_marketplace_listing(product, "ebay", %{
               provider: :gemini,
               model: "gemini-marketplace",
               output: %{
                 "generated_title" => "Generated eBay title",
                 "generated_description" => "Generated eBay description",
                 "generated_tags" => ["tag-one"],
                 "generated_price_suggestion" => 123,
                 "generation_version" => "gemini-marketplace-v1",
                 "compliance_warnings" => []
               }
             })

    assert listing.marketplace == "ebay"
    assert listing.generated_title == "Generated eBay title"

    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert refreshed_product.title == "User title"
    assert Enum.any?(refreshed_product.marketplace_listings, &(&1.id == listing.id))
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
