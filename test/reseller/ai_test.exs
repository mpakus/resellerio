defmodule Reseller.AITest do
  use ExUnit.Case, async: true

  alias Reseller.AI

  test "recognize_images/3 delegates to the configured provider" do
    images = [%{mime_type: "image/jpeg", data_base64: "abc123"}]
    attrs = %{"brand_hint" => "Nike"}

    assert {:ok, %{operation: :recognize_images, attrs: ^attrs, images: ^images}} =
             AI.recognize_images(images, attrs)

    assert_received {:ai_provider_called, :recognize_images, ^images, ^attrs, _opts}
  end

  test "generate_description/2 delegates to the configured provider" do
    attrs = %{"brand" => "Nike", "category" => "Sneakers"}

    assert {:ok, %{operation: :generate_description, attrs: ^attrs}} =
             AI.generate_description(attrs)

    assert_received {:ai_provider_called, :generate_description, ^attrs, _opts}
  end

  test "research_price/3 delegates to the configured provider" do
    attrs = %{"brand" => "Nike"}
    search_results = %{"matches" => [%{"title" => "Nike Air Max"}]}

    assert {:ok, %{operation: :research_price, attrs: ^attrs, search_results: ^search_results}} =
             AI.research_price(attrs, search_results)

    assert_received {:ai_provider_called, :research_price, ^attrs, ^search_results, _opts}
  end

  test "generate_marketplace_listing/2 delegates to the configured provider" do
    attrs = %{"marketplace" => "ebay", "product" => %{"brand" => "Nike"}}

    assert {:ok, %{operation: :generate_marketplace_listing, attrs: ^attrs}} =
             AI.generate_marketplace_listing(attrs)

    assert_received {:ai_provider_called, :generate_marketplace_listing, ^attrs, _opts}
  end

  test "reconcile_product/3 delegates to the configured provider" do
    recognition_result = %{"brand" => "Nike", "possible_model" => "Air Max 90"}
    search_results = %{"matches" => [%{"title" => "Nike Air Max 90"}]}

    assert {:ok,
            %{
              operation: :reconcile_product,
              recognition_result: ^recognition_result,
              search_results: ^search_results
            }} = AI.reconcile_product(recognition_result, search_results)

    assert_received {:ai_provider_called, :reconcile_product, ^recognition_result,
                     ^search_results, _opts}
  end
end
