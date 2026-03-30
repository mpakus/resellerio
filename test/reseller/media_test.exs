defmodule Reseller.MediaTest do
  use Reseller.DataCase, async: true

  alias Reseller.Catalog
  alias Reseller.Media

  test "generate_product_variants/2 creates background-removed and white-background variants" do
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

    assert Enum.map(variants, & &1.kind) == ["background_removed", "white_background"]
    assert Enum.all?(variants, &(&1.processing_status == "ready"))
    assert Enum.all?(variants, &(&1.position == 1))
    assert Enum.map(variants, & &1.background_style) == ["transparent", "white"]

    assert_received {:media_processor_called, "https://cdn.example.com/catalog/" <> _,
                     %{kind: "background_removed"}, _opts}

    assert_received {:media_processor_called, "https://cdn.example.com/catalog/" <> _,
                     %{kind: "white_background"}, _opts}

    assert_received {:media_storage_uploaded, "users/" <> _, _, _opts}
  end
end
