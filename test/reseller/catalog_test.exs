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
end
