defmodule Reseller.SearchTest do
  use ExUnit.Case, async: true

  alias Reseller.Search

  test "lens_matches/2 delegates to the configured provider" do
    image_url = "https://cdn.example.com/images/shoe.jpg"

    assert {:ok, %{image_url: ^image_url, search_type: :lens}} = Search.lens_matches(image_url)

    assert_received {:search_provider_called, :lens_matches, ^image_url, _opts}
  end

  test "shopping_matches/2 delegates to the configured provider" do
    query = "nike air max 90 mens"

    assert {:ok, %{query: ^query, search_type: :shopping}} = Search.shopping_matches(query)

    assert_received {:search_provider_called, :shopping_matches, ^query, _opts}
  end
end
