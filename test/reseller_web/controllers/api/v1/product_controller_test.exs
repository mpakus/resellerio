defmodule ResellerWeb.API.V1.ProductControllerTest do
  use ResellerWeb.ConnCase, async: true

  setup %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    {raw_token, _api_token} = api_token_fixture(user, %{"device_name" => "iPhone"})

    authed_conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")

    %{conn: authed_conn, user: user}
  end

  test "GET /api/v1/products lists only the current user's products", %{conn: conn, user: user} do
    _product = product_fixture(user, %{"title" => "Seller product"})
    other_user = user_fixture(%{"email" => "other@example.com"})
    _other_product = product_fixture(other_user, %{"title" => "Other product"})

    conn = get(conn, "/api/v1/products")

    assert %{"data" => %{"products" => [%{"title" => "Seller product"}]}} =
             json_response(conn, 200)
  end

  test "POST /api/v1/products creates a draft product without uploads", %{conn: conn} do
    conn =
      post(conn, "/api/v1/products", %{
        "product" => %{
          "title" => "Vintage blazer",
          "brand" => "Ralph Lauren",
          "category" => "Blazers"
        }
      })

    assert %{
             "data" => %{
               "product" => %{
                 "status" => "draft",
                 "title" => "Vintage blazer",
                 "images" => []
               },
               "upload_instructions" => []
             }
           } = json_response(conn, 201)
  end

  test "POST /api/v1/products creates upload instructions", %{conn: conn} do
    conn =
      post(conn, "/api/v1/products", %{
        "product" => %{
          "title" => "Nike Air Max",
          "brand" => "Nike",
          "category" => "Sneakers"
        },
        "uploads" => [
          %{
            "filename" => "shoe-1.jpg",
            "content_type" => "image/jpeg",
            "byte_size" => 345_678
          }
        ]
      })

    assert %{
             "data" => %{
               "product" => %{
                 "status" => "uploading",
                 "images" => [
                   %{
                     "content_type" => "image/jpeg",
                     "original_filename" => "shoe-1.jpg",
                     "processing_status" => "pending_upload"
                   }
                 ]
               },
               "upload_instructions" => [
                 %{
                   "method" => "PUT",
                   "headers" => %{"content-type" => "image/jpeg"},
                   "upload_url" => upload_url
                 }
               ]
             }
           } = json_response(conn, 201)

    assert upload_url =~ "https://uploads.example.test/"
    assert_received {:media_storage_called, _storage_key, _opts}
  end

  test "POST /api/v1/products validates upload payloads", %{conn: conn} do
    conn =
      post(conn, "/api/v1/products", %{
        "product" => %{"title" => "Bad upload"},
        "uploads" => [
          %{
            "filename" => "notes.txt",
            "content_type" => "text/plain",
            "byte_size" => -10
          }
        ]
      })

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "fields" => %{"uploads" => [%{"byte_size" => _, "content_type" => _}]}
             }
           } = json_response(conn, 422)
  end

  test "GET /api/v1/products/:id returns not found for another user's product", %{conn: conn} do
    other_user = user_fixture(%{"email" => "other@example.com"})
    product = product_fixture(other_user)

    conn = get(conn, "/api/v1/products/#{product.id}")

    assert json_response(conn, 404) == %{
             "error" => %{
               "code" => "not_found",
               "detail" => "Product not found",
               "status" => 404
             }
           }
  end

  test "POST /api/v1/products/:id/finalize_uploads marks uploads as uploaded", %{
    conn: conn,
    user: user
  } do
    {:ok, %{product: product}} =
      Reseller.Catalog.create_product_for_user(
        user,
        %{"title" => "Nike Air Max"},
        [
          %{"filename" => "shoe-1.jpg", "content_type" => "image/jpeg", "byte_size" => 345_678}
        ],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    conn =
      post(conn, "/api/v1/products/#{product.id}/finalize_uploads", %{
        "uploads" => [
          %{
            "id" => image.id,
            "checksum" => "abc123",
            "width" => 1200,
            "height" => 1600
          }
        ]
      })

    assert %{
             "data" => %{
               "product" => %{
                 "status" => "processing",
                 "images" => [
                   %{
                     "id" => image_id,
                     "processing_status" => "uploaded",
                     "checksum" => "abc123",
                     "width" => 1200,
                     "height" => 1600
                   }
                 ]
               },
               "finalized_images" => [%{"id" => finalized_id, "processing_status" => "uploaded"}]
             }
           } = json_response(conn, 200)

    assert image_id == image.id
    assert finalized_id == image.id
  end

  test "POST /api/v1/products/:id/finalize_uploads rejects image ids from another product", %{
    conn: conn,
    user: user
  } do
    {:ok, %{product: product}} =
      Reseller.Catalog.create_product_for_user(
        user,
        %{"title" => "Nike Air Max"},
        [
          %{"filename" => "shoe-1.jpg", "content_type" => "image/jpeg", "byte_size" => 345_678}
        ],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    {:ok, %{product: other_product}} =
      Reseller.Catalog.create_product_for_user(
        user,
        %{"title" => "Adidas Samba"},
        [
          %{"filename" => "shoe-2.jpg", "content_type" => "image/jpeg", "byte_size" => 345_679}
        ],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [other_image] = other_product.images

    conn =
      post(conn, "/api/v1/products/#{product.id}/finalize_uploads", %{
        "uploads" => [%{"id" => other_image.id}]
      })

    assert json_response(conn, 422) == %{
             "error" => %{
               "code" => "invalid_uploads",
               "detail" => "Uploads must belong to the selected product",
               "status" => 422
             }
           }
  end

  test "POST /api/v1/products/:id/finalize_uploads validates duplicate ids", %{
    conn: conn,
    user: user
  } do
    {:ok, %{product: product}} =
      Reseller.Catalog.create_product_for_user(
        user,
        %{"title" => "Nike Air Max"},
        [
          %{"filename" => "shoe-1.jpg", "content_type" => "image/jpeg", "byte_size" => 345_678}
        ],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    conn =
      post(conn, "/api/v1/products/#{product.id}/finalize_uploads", %{
        "uploads" => [%{"id" => image.id}, %{"id" => image.id}]
      })

    assert %{
             "error" => %{
               "code" => "validation_failed",
               "fields" => %{"uploads" => ["contains duplicate image ids"]},
               "status" => 422
             }
           } = json_response(conn, 422)
  end
end
