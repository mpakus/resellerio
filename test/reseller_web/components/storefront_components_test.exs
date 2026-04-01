defmodule ResellerWeb.StorefrontComponentsTest do
  use Reseller.DataCase, async: true

  alias Reseller.Media.ProductImage
  alias ResellerWeb.StorefrontComponents

  defp build_image(attrs) do
    struct(
      ProductImage,
      %{
        id: System.unique_integer([:positive]),
        kind: "original",
        position: 1,
        processing_status: "ready",
        seller_approved: false,
        storefront_visible: false,
        storefront_position: nil,
        lifestyle_generation_run_id: nil,
        source_image_ids: []
      }
      |> Map.merge(attrs)
    )
  end

  defp build_product(images) do
    struct(Reseller.Catalog.Product, images: images)
  end

  describe "storefront_gallery_images/1" do
    test "returns storefront_visible images sorted by storefront_position when any are visible" do
      img1 =
        build_image(%{
          id: 1,
          kind: "original",
          position: 1,
          storefront_visible: true,
          storefront_position: 3
        })

      img2 =
        build_image(%{
          id: 2,
          kind: "original",
          position: 2,
          storefront_visible: true,
          storefront_position: 1
        })

      img3 =
        build_image(%{
          id: 3,
          kind: "original",
          position: 3,
          storefront_visible: true,
          storefront_position: nil
        })

      img4 =
        build_image(%{
          id: 4,
          kind: "original",
          position: 4,
          storefront_visible: false,
          storefront_position: nil
        })

      result =
        StorefrontComponents.storefront_gallery_images(build_product([img1, img2, img3, img4]))

      assert Enum.map(result, & &1.id) == [2, 1, 3]
      refute 4 in Enum.map(result, & &1.id)
    end

    test "falls back to approved lifestyle-generated first, then background_removed, when no storefront_visible images" do
      original = build_image(%{id: 1, kind: "original", position: 1})
      bg_removed = build_image(%{id: 2, kind: "background_removed", position: 1})

      lifestyle_approved =
        build_image(%{id: 3, kind: "lifestyle_generated", position: 1, seller_approved: true})

      lifestyle_unapproved =
        build_image(%{id: 4, kind: "lifestyle_generated", position: 2, seller_approved: false})

      result =
        StorefrontComponents.storefront_gallery_images(
          build_product([original, bg_removed, lifestyle_approved, lifestyle_unapproved])
        )

      ids = Enum.map(result, & &1.id)

      assert 3 in ids
      assert 2 in ids
      refute 1 in ids
      refute 4 in ids

      lifestyle_idx = Enum.find_index(result, &(&1.id == 3))
      bg_idx = Enum.find_index(result, &(&1.id == 2))
      assert lifestyle_idx < bg_idx
    end

    test "falls back to originals only when no lifestyle-generated or background_removed images exist" do
      original1 = build_image(%{id: 1, kind: "original", position: 1})
      original2 = build_image(%{id: 2, kind: "original", position: 2})

      result =
        StorefrontComponents.storefront_gallery_images(build_product([original1, original2]))

      assert Enum.map(result, & &1.id) == [1, 2]
    end

    test "unapproved lifestyle_generated images are excluded from fallback" do
      original = build_image(%{id: 1, kind: "original", position: 1})

      lifestyle =
        build_image(%{id: 2, kind: "lifestyle_generated", position: 1, seller_approved: false})

      result =
        StorefrontComponents.storefront_gallery_images(build_product([original, lifestyle]))

      assert Enum.map(result, & &1.id) == [1]
    end

    test "excludes images with non-ready processing_status" do
      ready = build_image(%{id: 1, kind: "original", position: 1, processing_status: "ready"})

      processing =
        build_image(%{id: 2, kind: "original", position: 2, processing_status: "processing"})

      failed =
        build_image(%{
          id: 3,
          kind: "background_removed",
          position: 1,
          processing_status: "failed"
        })

      result =
        StorefrontComponents.storefront_gallery_images(build_product([ready, processing, failed]))

      assert Enum.map(result, & &1.id) == [1]
    end

    test "returns empty list when product has no images" do
      assert StorefrontComponents.storefront_gallery_images(build_product([])) == []
    end

    test "returns empty list when images are not loaded" do
      product = struct(Reseller.Catalog.Product, images: %Ecto.Association.NotLoaded{})
      assert StorefrontComponents.storefront_gallery_images(product) == []
    end

    test "fallback with only background_removed images shows them without originals" do
      bg1 = build_image(%{id: 1, kind: "background_removed", position: 1})
      bg2 = build_image(%{id: 2, kind: "background_removed", position: 2})

      result = StorefrontComponents.storefront_gallery_images(build_product([bg1, bg2]))

      assert Enum.map(result, & &1.id) == [1, 2]
    end

    test "fallback with only approved lifestyle images shows them without originals" do
      lifestyle1 =
        build_image(%{id: 1, kind: "lifestyle_generated", position: 7, seller_approved: true})

      lifestyle2 =
        build_image(%{id: 2, kind: "lifestyle_generated", position: 8, seller_approved: true})

      original = build_image(%{id: 3, kind: "original", position: 1})

      result =
        StorefrontComponents.storefront_gallery_images(
          build_product([lifestyle1, lifestyle2, original])
        )

      assert Enum.map(result, & &1.id) == [1, 2]
      refute 3 in Enum.map(result, & &1.id)
    end

    test "storefront_visible images include all ready kinds when visible" do
      bg_visible =
        build_image(%{
          id: 1,
          kind: "background_removed",
          position: 1,
          storefront_visible: true,
          storefront_position: 1
        })

      lifestyle_visible =
        build_image(%{
          id: 2,
          kind: "lifestyle_generated",
          position: 7,
          seller_approved: true,
          storefront_visible: true,
          storefront_position: 2
        })

      original_hidden =
        build_image(%{id: 3, kind: "original", position: 1, storefront_visible: false})

      result =
        StorefrontComponents.storefront_gallery_images(
          build_product([bg_visible, lifestyle_visible, original_hidden])
        )

      assert Enum.map(result, & &1.id) == [1, 2]
    end
  end
end
