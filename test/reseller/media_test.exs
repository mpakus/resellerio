defmodule Reseller.MediaTest do
  use Reseller.DataCase, async: true

  alias Reseller.AI
  alias Reseller.Catalog
  alias Reseller.Media

  test "generate_product_variants/2 creates a background-removed variant for each upload" do
    user = user_fixture()

    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Sneakers"},
        [%{"filename" => "shoe.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    {:ok, %{product: finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    assert {:ok, variants} =
             Media.generate_product_variants(finalized_product,
               public_base_url: "https://cdn.example.com/catalog",
               media_processor: Reseller.Support.Fakes.MediaProcessor,
               storage: Reseller.Support.Fakes.MediaStorage
             )

    assert Enum.map(variants, & &1.kind) == ["background_removed"]
    assert Enum.all?(variants, &(&1.processing_status == "ready"))
    assert Enum.all?(variants, &(&1.position == 1))
    assert Enum.map(variants, & &1.background_style) == ["transparent"]

    assert_received {:media_processor_called, "https://cdn.example.com/catalog/" <> _,
                     %{kind: "background_removed"}, _opts}

    assert_received {:media_storage_uploaded, "users/" <> _, _, _opts}
  end

  test "public_url_for_storage_key/2 supports endpoint-style Tigris config with bucket_name" do
    assert {:ok,
            "https://reseller-images.t3.storage.dev/users/1/products/2/originals/example.jpg"} =
             Media.public_url_for_storage_key(
               "users/1/products/2/originals/example.jpg",
               config: [
                 base_url: "https://t3.storage.dev",
                 bucket_name: "reseller-images"
               ]
             )
  end

  test "create_lifestyle_generated_image/2 stores run metadata and appends after existing images" do
    user = user_fixture()
    product = finalized_product_fixture(user)
    [original_image] = product.images

    assert {:ok, run} =
             AI.create_product_lifestyle_generation_run(product, %{
               "status" => "completed",
               "step" => "lifestyle_generated",
               "scene_family" => "apparel",
               "model" => "gemini-2.5-flash-image",
               "prompt_version" => "v1",
               "requested_count" => 1,
               "completed_count" => 1,
               "payload" => %{"summary" => "Generated one lifestyle preview."}
             })

    assert {:ok, generated_image} =
             Media.create_lifestyle_generated_image(product, %{
               "storage_key" => "users/#{user.id}/products/#{product.id}/generated/look-1.png",
               "content_type" => "image/png",
               "byte_size" => 456_000,
               "checksum" => "generated123",
               "width" => 1024,
               "height" => 1280,
               "original_filename" => "look-1.png",
               "lifestyle_generation_run_id" => run.id,
               "scene_key" => "model_studio",
               "variant_index" => 1,
               "source_image_ids" => [original_image.id]
             })

    assert generated_image.kind == "lifestyle_generated"
    assert generated_image.position == 2
    assert generated_image.processing_status == "ready"
    assert generated_image.background_style == "lifestyle"
    assert generated_image.scene_key == "model_studio"
    assert generated_image.variant_index == 1
    assert generated_image.source_image_ids == [original_image.id]
    assert generated_image.lifestyle_generation_run_id == run.id

    reloaded_product = Catalog.get_product_for_user(user, product.id)
    reloaded_generated = Enum.find(reloaded_product.images, &(&1.id == generated_image.id))

    assert reloaded_generated.kind == "lifestyle_generated"
    assert reloaded_generated.position == 2
    assert reloaded_generated.scene_key == "model_studio"
  end

  test "approve_lifestyle_generated_image/2 and delete_lifestyle_generated_image/2 manage seller review state" do
    user = user_fixture()
    product = finalized_product_fixture(user)
    [original_image] = product.images

    {:ok, run} =
      AI.create_product_lifestyle_generation_run(product, %{
        "status" => "completed",
        "step" => "lifestyle_generated",
        "scene_family" => "apparel",
        "model" => "gemini-2.5-flash-image",
        "prompt_version" => "v1",
        "requested_count" => 1,
        "completed_count" => 1,
        "payload" => %{"summary" => "Generated one lifestyle preview."}
      })

    {:ok, generated_image} =
      Media.create_lifestyle_generated_image(product, %{
        "storage_key" => "users/#{user.id}/products/#{product.id}/generated/look-2.png",
        "content_type" => "image/png",
        "byte_size" => 456_000,
        "checksum" => "generated456",
        "width" => 1024,
        "height" => 1280,
        "original_filename" => "look-2.png",
        "lifestyle_generation_run_id" => run.id,
        "scene_key" => "casual_lifestyle",
        "variant_index" => 2,
        "source_image_ids" => [original_image.id]
      })

    assert {:ok, approved_image} =
             Media.approve_lifestyle_generated_image(product, generated_image.id)

    assert approved_image.seller_approved
    assert %DateTime{} = approved_image.approved_at

    assert {:ok, _deleted_image} =
             Media.delete_lifestyle_generated_image(product, generated_image.id)

    refute Media.get_lifestyle_generated_image(product, generated_image.id)
  end

  test "delete_product_image/2 removes the original, its generated variant, and dependent lifestyle previews" do
    user = user_fixture()
    product = finalized_product_fixture(user)
    [original_image] = product.images

    assert {:ok, [_background_removed]} =
             Media.generate_product_variants(product,
               public_base_url: "https://cdn.example.com/catalog",
               media_processor: Reseller.Support.Fakes.MediaProcessor,
               storage: Reseller.Support.Fakes.MediaStorage
             )

    {:ok, run} =
      AI.create_product_lifestyle_generation_run(product, %{
        "status" => "completed",
        "step" => "lifestyle_generated",
        "scene_family" => "apparel",
        "model" => "gemini-2.5-flash-image",
        "prompt_version" => "v1",
        "requested_count" => 1,
        "completed_count" => 1,
        "payload" => %{"summary" => "Generated one lifestyle preview."}
      })

    {:ok, _generated_image} =
      Media.create_lifestyle_generated_image(product, %{
        "storage_key" => "users/#{user.id}/products/#{product.id}/generated/look-1.png",
        "content_type" => "image/png",
        "byte_size" => 456_000,
        "checksum" => "generated123",
        "width" => 1024,
        "height" => 1280,
        "original_filename" => "look-1.png",
        "lifestyle_generation_run_id" => run.id,
        "scene_key" => "model_studio",
        "variant_index" => 1,
        "source_image_ids" => [original_image.id]
      })

    assert {:ok, %{deleted_image_ids: deleted_image_ids}} =
             Media.delete_product_image(product, original_image.id)

    assert length(deleted_image_ids) == 3

    refreshed_product = Catalog.get_product_for_user(user, product.id)
    assert refreshed_product.images == []
  end

  defp finalized_product_fixture(user) do
    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Studio jacket"},
        [%{"filename" => "jacket.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
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
