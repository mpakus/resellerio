defmodule Reseller.CatalogTest do
  use Reseller.DataCase, async: true

  import Ecto.Query

  alias Reseller.Catalog
  alias Reseller.Repo

  test "create_product_for_user/4 creates a draft product without uploads" do
    user = user_fixture()

    assert {:ok, %{product: product, upload_bundle: upload_bundle}} =
             Catalog.create_product_for_user(user, %{
               "title" => "Vintage blazer",
               "brand" => "Ralph Lauren",
               "category" => "Blazers",
               "tags" => "vintage, blazer, wool"
             })

    assert product.user_id == user.id
    assert product.status == "draft"
    assert product.tags == ["vintage", "blazer", "wool"]
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

  test "paginate_products_for_user/2 paginates, sorts, and filters by updated_at" do
    user = user_fixture()

    alpha =
      product_fixture(user, %{"title" => "Alpha jacket", "status" => "ready", "price" => "55.00"})

    beta =
      product_fixture(user, %{"title" => "Beta jacket", "status" => "ready", "price" => "75.00"})

    sold =
      product_fixture(user, %{"title" => "Sold jacket", "status" => "sold", "price" => "25.00"})

    from(p in Reseller.Catalog.Product, where: p.id == ^alpha.id)
    |> Repo.update_all(set: [updated_at: ~U[2024-01-10 12:00:00Z]])

    from(p in Reseller.Catalog.Product, where: p.id == ^beta.id)
    |> Repo.update_all(set: [updated_at: ~U[2024-02-10 12:00:00Z]])

    from(p in Reseller.Catalog.Product, where: p.id == ^sold.id)
    |> Repo.update_all(set: [updated_at: ~U[2024-03-10 12:00:00Z]])

    page =
      Catalog.paginate_products_for_user(user,
        status: "ready",
        updated_from: ~D[2024-02-01],
        sort: :title,
        sort_dir: :desc,
        page_size: 1
      )

    assert page.total_count == 1
    assert page.total_pages == 1
    assert page.page == 1
    assert [%{title: "Beta jacket"}] = page.entries
  end

  test "get_product_for_user/2 returns nil for another user's product" do
    user = user_fixture()
    other_user = user_fixture()
    product = product_fixture(other_user)

    assert Catalog.get_product_for_user(user, product.id) == nil
  end

  test "update_product_for_user/3 updates editable fields and allows seller-managed status changes" do
    user = user_fixture()

    product =
      product_fixture(user, %{"title" => "Before", "status" => "draft", "source" => "manual"})

    assert {:ok, updated_product} =
             Catalog.update_product_for_user(user, product.id, %{
               "title" => "After",
               "brand" => "Patagonia",
               "price" => "99.00",
               "status" => "sold",
               "tags" => "technical, shell, winter",
               "source" => "import"
             })

    assert updated_product.title == "After"
    assert updated_product.brand == "Patagonia"
    assert Decimal.equal?(updated_product.price, Decimal.new("99.00"))
    assert updated_product.status == "sold"
    assert updated_product.tags == ["technical", "shell", "winter"]
    assert updated_product.sold_at
    assert updated_product.source == "manual"
  end

  test "update_product_for_user/3 rejects system-only statuses in seller updates" do
    user = user_fixture()
    product = product_fixture(user, %{"title" => "Before", "status" => "draft"})

    assert {:error, changeset} =
             Catalog.update_product_for_user(user, product.id, %{"status" => "processing"})

    assert %{status: ["is invalid"]} = errors_on(changeset)
  end

  test "delete_product_for_user/2 deletes the product" do
    user = user_fixture()
    product = product_fixture(user, %{"title" => "Delete me"})

    assert {:ok, _deleted_product} = Catalog.delete_product_for_user(user, product.id)
    assert Catalog.get_product_for_user(user, product.id) == nil
  end

  test "mark_product_sold_for_user/3 marks the product as sold" do
    user = user_fixture()
    product = product_fixture(user, %{"status" => "ready", "title" => "Sold product"})

    assert {:ok, sold_product} = Catalog.mark_product_sold_for_user(user, product.id)

    assert sold_product.status == "sold"
    assert sold_product.sold_at
    assert sold_product.archived_at == nil
  end

  test "archive_product_for_user/2 archives the product" do
    user = user_fixture()
    product = product_fixture(user, %{"status" => "ready", "title" => "Archive me"})

    assert {:ok, archived_product} = Catalog.archive_product_for_user(user, product.id)

    assert archived_product.status == "archived"
    assert archived_product.archived_at
  end

  test "unarchive_product_for_user/2 restores archived products to sold when sold_at is present" do
    user = user_fixture()

    product =
      product_fixture(user, %{
        "status" => "archived",
        "sold_at" => DateTime.utc_now() |> DateTime.truncate(:second),
        "archived_at" => DateTime.utc_now() |> DateTime.truncate(:second)
      })

    assert {:ok, restored_product} = Catalog.unarchive_product_for_user(user, product.id)

    assert restored_product.status == "sold"
    assert restored_product.archived_at == nil
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

    assert {:ok,
            %{
              product: finalized_product,
              finalized_images: finalized_images,
              processing_run: processing_run
            }} =
             Catalog.finalize_product_uploads_for_user(user, product.id, [
               %{"id" => image_one.id, "checksum" => "abc", "width" => 1200, "height" => 1600},
               %{"id" => image_two.id, "checksum" => "def", "width" => 1201, "height" => 1601}
             ])

    assert finalized_product.status == "processing"
    assert Enum.all?(finalized_images, &(&1.processing_status == "uploaded"))
    assert Enum.all?(finalized_product.images, &(&1.processing_status == "processing"))
    assert processing_run.status == "completed"
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
