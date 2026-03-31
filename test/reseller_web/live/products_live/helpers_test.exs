defmodule ResellerWeb.ProductsLive.HelpersTest do
  use ExUnit.Case, async: true

  alias Reseller.AI.ProductDescriptionDraft
  alias Reseller.Catalog.Product
  alias ResellerWeb.ProductsLive.Helpers

  test "suggested_product_tags/1 seeds lowercase tags from brand, category, and ai description" do
    product = %Product{
      brand: "Nike",
      category: "Sneakers",
      tags: [],
      description_draft: %ProductDescriptionDraft{
        short_description: "Retro runners streetwear"
      }
    }

    assert Helpers.suggested_product_tags(product) == [
             "nike",
             "sneakers",
             "retro",
             "runners",
             "streetwear"
           ]
  end

  test "suggested_product_tags/1 preserves saved tags when the seller already set them" do
    product = %Product{
      brand: "Nike",
      category: "Sneakers",
      tags: ["Vintage", "Running"],
      description_draft: %ProductDescriptionDraft{
        short_description: "Retro runners streetwear"
      }
    }

    assert Helpers.suggested_product_tags(product) == ["vintage", "running"]
  end
end
