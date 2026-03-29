defmodule Reseller.Workers.AIProductProcessorTest do
  use Reseller.DataCase, async: true

  alias Reseller.Catalog
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
               recognize_result: recognize_result
             )

    assert run.status == "completed"
    assert run.step == "recognition_completed"
    assert run.payload["pipeline_status"] == "recognized"
    assert run.payload["final"]["brand"] == "Nike"

    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert refreshed_product.status == "ready"
    assert refreshed_product.title == "Nike Air Max 90"
    assert refreshed_product.brand == "Nike"
    assert refreshed_product.category == "Sneakers"
    assert refreshed_product.color == "White"
    assert refreshed_product.material == "Mesh"
    assert refreshed_product.ai_summary == "visible air unit, mesh upper"
    assert refreshed_product.ai_confidence == 0.91
    assert Enum.all?(refreshed_product.images, &(&1.processing_status == "ready"))

    assert_received {:ai_provider_called, :recognize_images, [image_input], metadata, _opts}
    assert image_input.kind == "original"
    assert image_input.mime_type == "image/jpeg"
    assert image_input.uri =~ "/users/#{user.id}/products/#{product.id}/originals/"
    assert metadata["existing_title"] == nil

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
               reconcile_result: reconcile_result
             )

    assert run.status == "completed"
    assert run.step == "recognition_completed"
    assert run.payload["pipeline_status"] == "reconciled"
    assert length(run.payload["search_matches"]) == 1
    assert run.payload["final"]["possible_model"] == "Tabby 26"

    refreshed_product = Catalog.get_product_for_user(user, product.id)

    assert refreshed_product.status == "review"
    assert refreshed_product.title == "Coach Tabby 26 shoulder bag"
    assert refreshed_product.brand == "Coach"
    assert refreshed_product.category == "Shoulder Bag"
    assert refreshed_product.ai_summary == "Coach Tabby 26 shoulder bag"
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
