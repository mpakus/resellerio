defmodule Reseller.Search.Providers.SerpApiTest do
  use ExUnit.Case, async: true

  alias Reseller.Search.Providers.SerpApi

  @config [
    api_key: "serp-key",
    base_url: "https://serpapi.example.test/search",
    shopping_engine: "google_shopping_light",
    default_language: "en",
    default_country: "us",
    timeout: 3_000
  ]

  test "lens_matches/2 builds a Google Lens request and normalizes results" do
    request_fun = fn request ->
      assert request.method == :get
      assert request.url == "https://serpapi.example.test/search"
      assert request.receive_timeout == 3_000
      assert request.params["api_key"] == "serp-key"
      assert request.params["engine"] == "google_lens"
      assert request.params["url"] == "https://cdn.example.com/items/shoe.jpg"
      assert request.params["q"] == "nike air max 90"

      {:ok,
       %{
         status: 200,
         body: %{
           "visual_matches" => [
             %{
               "title" => "Nike Air Max 90",
               "link" => "https://www.ebay.com/itm/123",
               "price" => "$120.00",
               "source" => "eBay"
             }
           ],
           "products" => [
             %{
               "title" => "Nike Air Max 90 Infrared",
               "link" => "https://poshmark.com/listing/abc",
               "extracted_price" => 95.0,
               "source" => "Poshmark"
             }
           ]
         }
       }}
    end

    assert {:ok, result} =
             SerpApi.lens_matches(
               "https://cdn.example.com/items/shoe.jpg",
               query: "nike air max 90",
               config: @config,
               request_fun: request_fun
             )

    assert result.provider == :serp_api
    assert result.search_type == :lens
    assert Enum.count(result.matches) == 2

    assert Enum.any?(result.matches, fn match ->
             match["title"] == "Nike Air Max 90" and match["price"] == 120.0 and
               match["source_domain"] == "www.ebay.com"
           end)

    assert Enum.any?(result.matches, fn match ->
             match["title"] == "Nike Air Max 90 Infrared" and match["price"] == 95.0 and
               match["match_type"] == "product"
           end)
  end

  test "shopping_matches/2 builds a shopping request and normalizes price strings" do
    request_fun = fn request ->
      assert request.method == :get
      assert request.url == "https://serpapi.example.test/search"
      assert request.params["engine"] == "google_shopping_light"
      assert request.params["q"] == "nike air max 90 men"

      {:ok,
       %{
         status: 200,
         body: %{
           "shopping_results" => [
             %{
               "title" => "Nike Air Max 90 Men",
               "link" => "https://www.goat.com/sneakers/air-max-90",
               "price" => "$140.50",
               "source" => "GOAT"
             }
           ]
         }
       }}
    end

    assert {:ok, result} =
             SerpApi.shopping_matches(
               "nike air max 90 men",
               config: @config,
               request_fun: request_fun
             )

    assert result.search_type == :shopping

    assert result.matches == [
             %{
               "brand" => "GOAT",
               "match_type" => "shopping",
               "price" => 140.5,
               "source" => "GOAT",
               "source_domain" => "www.goat.com",
               "thumbnail_url" => nil,
               "title" => "Nike Air Max 90 Men",
               "url" => "https://www.goat.com/sneakers/air-max-90"
             }
           ]
  end

  test "returns an error when the api key is missing" do
    assert {:error, :missing_api_key} =
             SerpApi.shopping_matches("nike air max 90",
               config: Keyword.delete(@config, :api_key)
             )
  end
end
