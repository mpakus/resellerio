defmodule ResellerWeb.WorkspaceLiveConfigTest do
  use ResellerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "shows a friendly storage configuration error when image uploads are not configured", %{
    conn: conn
  } do
    user = user_fixture(%{"email" => "seller@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    with_tigris_storage_missing!(:access_key_id, fn ->
      {:ok, view, _html} = live(conn, "/app/products")

      upload =
        file_input(view, "#new-product-form", :product_images, [
          %{
            name: "jacket.jpg",
            content: "fake-image-binary",
            type: "image/jpeg"
          }
        ])

      assert render_upload(upload, "jacket.jpg") =~ "jacket.jpg"

      view
      |> form("#new-product-form",
        product: %{
          title: "Web Jacket",
          brand: "Levi's",
          category: "Outerwear"
        }
      )
      |> render_submit()

      assert has_element?(
               view,
               "#flash-error",
               "Could not create product: missing configuration: TIGRIS_ACCESS_KEY_ID. Add it to your .env or shell and restart Phoenix."
             )
    end)
  end

  test "shows a friendly bucket-name error for endpoint-style Tigris config", %{conn: conn} do
    user = user_fixture(%{"email" => "seller2@example.com"})
    conn = init_test_session(conn, %{user_id: user.id})

    with_tigris_storage_missing!(:bucket_name, fn ->
      {:ok, view, _html} = live(conn, "/app/products")

      upload =
        file_input(view, "#new-product-form", :product_images, [
          %{
            name: "jacket.jpg",
            content: "fake-image-binary",
            type: "image/jpeg"
          }
        ])

      assert render_upload(upload, "jacket.jpg") =~ "jacket.jpg"

      view
      |> form("#new-product-form",
        product: %{
          title: "Web Jacket",
          brand: "Levi's",
          category: "Outerwear"
        }
      )
      |> render_submit()

      assert has_element?(
               view,
               "#flash-error",
               "Could not create product: missing configuration: TIGRIS_BUCKET_NAME. Add it to your .env or shell and restart Phoenix."
             )
    end)
  end

  defp with_tigris_storage_missing!(missing_key, fun) do
    previous_media = Application.get_env(:reseller, Reseller.Media)
    previous_tigris = Application.get_env(:reseller, Reseller.Media.Storage.Tigris)

    Application.put_env(
      :reseller,
      Reseller.Media,
      Keyword.put(previous_media, :storage, Reseller.Media.Storage.Tigris)
    )

    Application.put_env(
      :reseller,
      Reseller.Media.Storage.Tigris,
      access_key_id: if(missing_key == :access_key_id, do: nil, else: "tigris-access"),
      secret_access_key: if(missing_key == :secret_access_key, do: nil, else: "tigris-secret"),
      base_url:
        if(missing_key == :base_url,
          do: nil,
          else:
            if(missing_key == :bucket_name,
              do: "https://t3.storage.dev",
              else: "https://bucket.example.tigris.dev"
            )
        ),
      bucket_name: if(missing_key == :bucket_name, do: nil, else: "reseller-images")
    )

    try do
      fun.()
    after
      Application.put_env(:reseller, Reseller.Media, previous_media)
      Application.put_env(:reseller, Reseller.Media.Storage.Tigris, previous_tigris)
    end
  end
end
