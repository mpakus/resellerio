defmodule Reseller.CatalogTest do
  use Reseller.DataCase, async: true

  alias Reseller.Catalog

  test "create_product_for_user/4 creates a draft product without uploads" do
    user = user_fixture()

    assert {:ok, %{product: product, upload_bundle: upload_bundle}} =
             Catalog.create_product_for_user(user, %{
               "title" => "Vintage blazer",
               "brand" => "Ralph Lauren",
               "category" => "Blazers"
             })

    assert product.user_id == user.id
    assert product.status == "draft"
    assert upload_bundle.images == []
    assert upload_bundle.upload_instructions == []
  end

  test "create_product_for_user/4 creates upload placeholders and instructions" do
    user = user_fixture()

    assert {:ok, %{product: product, upload_bundle: upload_bundle}} =
             Catalog.create_product_for_user(
               user,
               %{"title" => "Nike sneakers"},
               [
                 %{
                   "filename" => "shoe-1.jpg",
                   "content_type" => "image/jpeg",
                   "byte_size" => 345_678
                 }
               ],
               storage: Reseller.Support.Fakes.MediaStorage
             )

    assert product.status == "uploading"
    assert Enum.count(product.images) == 1
    assert Enum.count(upload_bundle.upload_instructions) == 1

    [image] = product.images
    [instruction] = upload_bundle.upload_instructions

    assert image.processing_status == "pending_upload"
    assert image.original_filename == "shoe-1.jpg"
    assert instruction["image_id"] == image.id
    assert instruction["storage_key"] == image.storage_key
    assert instruction["method"] == "PUT"
  end

  test "list_products_for_user/1 returns only the signed-in user's products" do
    user = user_fixture()
    other_user = user_fixture()
    product = product_fixture(user, %{"title" => "User product"})
    _other_product = product_fixture(other_user, %{"title" => "Other product"})

    assert [%{id: id, title: "User product"}] = Catalog.list_products_for_user(user)
    assert id == product.id
  end

  test "get_product_for_user/2 returns nil for another user's product" do
    user = user_fixture()
    other_user = user_fixture()
    product = product_fixture(other_user)

    assert Catalog.get_product_for_user(user, product.id) == nil
  end

  test "finalize_product_uploads_for_user/3 marks uploaded images and moves the product to processing" do
    user = user_fixture()

    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Nike sneakers"},
        [
          %{"filename" => "shoe-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000},
          %{"filename" => "shoe-2.jpg", "content_type" => "image/jpeg", "byte_size" => 124_000}
        ],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image_one, image_two] = product.images

    assert {:ok, %{product: finalized_product, finalized_images: finalized_images}} =
             Catalog.finalize_product_uploads_for_user(user, product.id, [
               %{"id" => image_one.id, "checksum" => "abc", "width" => 1200, "height" => 1600},
               %{"id" => image_two.id, "checksum" => "def", "width" => 1201, "height" => 1601}
             ])

    assert finalized_product.status == "processing"
    assert Enum.all?(finalized_images, &(&1.processing_status == "uploaded"))
    assert Enum.all?(finalized_product.images, &(&1.processing_status == "uploaded"))
  end

  test "finalize_product_uploads_for_user/3 rejects another user's image ids" do
    user = user_fixture()
    other_user = user_fixture()

    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Nike sneakers"},
        [%{"filename" => "shoe-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    {:ok, %{product: other_product}} =
      Catalog.create_product_for_user(
        other_user,
        %{"title" => "Other sneakers"},
        [%{"filename" => "other.jpg", "content_type" => "image/jpeg", "byte_size" => 111_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [other_image] = other_product.images

    assert {:error, :invalid_product_images} =
             Catalog.finalize_product_uploads_for_user(user, product.id, [
               %{"id" => other_image.id}
             ])
  end
end
