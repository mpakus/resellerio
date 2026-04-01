defmodule Reseller.ImageSelectTest do
  use Reseller.DataCase, async: true

  alias Reseller.Catalog
  alias Reseller.Media
  alias Reseller.Repo
  alias Reseller.Media.ProductImage

  defp setup_product_with_ready_images(user) do
    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Test Product"},
        [
          %{"filename" => "img1.jpg", "content_type" => "image/jpeg", "byte_size" => 10_000},
          %{"filename" => "img2.jpg", "content_type" => "image/jpeg", "byte_size" => 10_000}
        ],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [img1, img2] = product.images

    {:ok, %{product: product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => img1.id, "checksum" => "aaa", "width" => 1000, "height" => 1000},
        %{"id" => img2.id, "checksum" => "bbb", "width" => 1000, "height" => 1000}
      ])

    Repo.update_all(
      from(pi in ProductImage, where: pi.product_id == ^product.id and pi.kind == "original"),
      set: [processing_status: "ready"]
    )

    product = Catalog.get_product_for_user(user, product.id)
    {product, Enum.filter(product.images, &(&1.kind == "original"))}
  end

  describe "update_image_storefront_settings_for_user/4" do
    test "sets storefront_visible on an owned image" do
      user = user_fixture()
      {product, [img1, _img2]} = setup_product_with_ready_images(user)

      assert {:ok, updated_product} =
               Catalog.update_image_storefront_settings_for_user(
                 user,
                 product.id,
                 img1.id,
                 %{"storefront_visible" => true}
               )

      updated_img = Enum.find(updated_product.images, &(&1.id == img1.id))
      assert updated_img.storefront_visible == true
    end

    test "sets storefront_position on an owned image" do
      user = user_fixture()
      {product, [img1, _img2]} = setup_product_with_ready_images(user)

      assert {:ok, updated_product} =
               Catalog.update_image_storefront_settings_for_user(
                 user,
                 product.id,
                 img1.id,
                 %{"storefront_position" => 5}
               )

      updated_img = Enum.find(updated_product.images, &(&1.id == img1.id))
      assert updated_img.storefront_position == 5
    end

    test "returns :not_found for another user's product" do
      user = user_fixture()
      other_user = user_fixture()
      {product, [img1, _img2]} = setup_product_with_ready_images(user)

      assert {:error, :not_found} =
               Catalog.update_image_storefront_settings_for_user(
                 other_user,
                 product.id,
                 img1.id,
                 %{"storefront_visible" => true}
               )
    end

    test "returns :not_found for an image that does not belong to the product" do
      user = user_fixture()
      {product, _images} = setup_product_with_ready_images(user)
      {_other_product, [other_img, _]} = setup_product_with_ready_images(user)

      assert {:error, :not_found} =
               Catalog.update_image_storefront_settings_for_user(
                 user,
                 product.id,
                 other_img.id,
                 %{"storefront_visible" => true}
               )
    end
  end

  describe "reorder_storefront_images_for_user/3" do
    test "assigns storefront_position in the supplied order" do
      user = user_fixture()
      {product, [img1, img2]} = setup_product_with_ready_images(user)

      assert {:ok, updated_product} =
               Catalog.reorder_storefront_images_for_user(user, product.id, [img2.id, img1.id])

      updated_img1 = Enum.find(updated_product.images, &(&1.id == img1.id))
      updated_img2 = Enum.find(updated_product.images, &(&1.id == img2.id))
      assert updated_img2.storefront_position == 1
      assert updated_img1.storefront_position == 2
    end

    test "returns :not_found for another user's product" do
      user = user_fixture()
      other_user = user_fixture()
      {product, [img1, img2]} = setup_product_with_ready_images(user)

      assert {:error, :not_found} =
               Catalog.reorder_storefront_images_for_user(other_user, product.id, [
                 img1.id,
                 img2.id
               ])
    end
  end

  describe "storefront_gallery_images/1 visibility and ordering" do
    alias ResellerWeb.StorefrontComponents

    test "returns all ready originals ordered by position when none are visible" do
      user = user_fixture()
      {product, [img1, img2]} = setup_product_with_ready_images(user)

      gallery = StorefrontComponents.storefront_gallery_images(product)
      assert length(gallery) == 2
      assert Enum.map(gallery, & &1.id) == [img1.id, img2.id]
    end

    test "returns only visible images ordered by storefront_position when any are visible" do
      user = user_fixture()
      {product, [img1, img2]} = setup_product_with_ready_images(user)

      {:ok, product} =
        Catalog.update_image_storefront_settings_for_user(user, product.id, img2.id, %{
          "storefront_visible" => true,
          "storefront_position" => 1
        })

      {:ok, product} =
        Catalog.update_image_storefront_settings_for_user(user, product.id, img1.id, %{
          "storefront_visible" => true,
          "storefront_position" => 2
        })

      gallery = StorefrontComponents.storefront_gallery_images(product)
      assert Enum.map(gallery, & &1.id) == [img2.id, img1.id]
    end

    test "excludes non-ready images even when visible" do
      user = user_fixture()
      {product, [img1, _img2]} = setup_product_with_ready_images(user)

      Repo.update_all(
        from(pi in ProductImage, where: pi.id == ^img1.id),
        set: [processing_status: "processing", storefront_visible: true]
      )

      product = Catalog.get_product_for_user(user, product.id)
      gallery = StorefrontComponents.storefront_gallery_images(product)
      refute Enum.any?(gallery, &(&1.id == img1.id))
    end
  end

  describe "Media storefront helpers" do
    test "update_product_image_storefront_settings/3 returns :not_found for wrong product" do
      user = user_fixture()
      {_product, [img1, _]} = setup_product_with_ready_images(user)
      {other_product, _} = setup_product_with_ready_images(user)

      assert {:error, :not_found} =
               Media.update_product_image_storefront_settings(
                 other_product,
                 img1.id,
                 %{"storefront_visible" => true}
               )
    end

    test "reorder_product_images_storefront_position/2 sets positions in transaction" do
      user = user_fixture()
      {product, [img1, img2]} = setup_product_with_ready_images(user)

      assert {:ok, _changes} =
               Media.reorder_product_images_storefront_position(product, [img2.id, img1.id])

      db_img1 = Repo.get(ProductImage, img1.id)
      db_img2 = Repo.get(ProductImage, img2.id)
      assert db_img2.storefront_position == 1
      assert db_img1.storefront_position == 2
    end
  end
end
