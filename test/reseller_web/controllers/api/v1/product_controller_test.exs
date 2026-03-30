defmodule ResellerWeb.API.V1.ProductControllerTest do
  use ResellerWeb.ConnCase, async: true

  alias Reseller.AI

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

  test "PATCH /api/v1/products/:id updates editable fields only", %{conn: conn, user: user} do
    product =
      product_fixture(user, %{"title" => "Before", "status" => "draft", "source" => "manual"})

    conn =
      patch(conn, "/api/v1/products/#{product.id}", %{
        "product" => %{
          "title" => "After",
          "brand" => "Arc'teryx",
          "status" => "sold",
          "source" => "import"
        }
      })

    assert %{
             "data" => %{
               "product" => %{
                 "title" => "After",
                 "brand" => "Arc'teryx",
                 "status" => "draft",
                 "source" => "manual"
               }
             }
           } = json_response(conn, 200)
  end

  test "DELETE /api/v1/products/:id deletes the product", %{conn: conn, user: user} do
    product = product_fixture(user, %{"title" => "Delete me"})

    conn = delete(conn, "/api/v1/products/#{product.id}")

    assert json_response(conn, 200) == %{"data" => %{"deleted" => true}}

    conn = get(conn, "/api/v1/products/#{product.id}")

    assert json_response(conn, 404) == %{
             "error" => %{
               "code" => "not_found",
               "detail" => "Product not found",
               "status" => 404
             }
           }
  end

  test "POST /api/v1/products/:id/mark_sold marks the product as sold", %{conn: conn, user: user} do
    product = product_fixture(user, %{"status" => "ready", "title" => "Ready to sell"})

    conn = post(conn, "/api/v1/products/#{product.id}/mark_sold", %{})

    assert %{
             "data" => %{
               "product" => %{
                 "status" => "sold",
                 "sold_at" => sold_at,
                 "archived_at" => nil
               }
             }
           } = json_response(conn, 200)

    assert is_binary(sold_at)
  end

  test "POST /api/v1/products/:id/archive archives the product", %{conn: conn, user: user} do
    product = product_fixture(user, %{"status" => "ready", "title" => "Archive me"})

    conn = post(conn, "/api/v1/products/#{product.id}/archive", %{})

    assert %{
             "data" => %{
               "product" => %{
                 "status" => "archived",
                 "archived_at" => archived_at
               }
             }
           } = json_response(conn, 200)

    assert is_binary(archived_at)
  end

  test "POST /api/v1/products/:id/unarchive restores the product to sold when sold_at exists", %{
    conn: conn,
    user: user
  } do
    product =
      product_fixture(user, %{
        "status" => "archived",
        "sold_at" => DateTime.utc_now() |> DateTime.truncate(:second),
        "archived_at" => DateTime.utc_now() |> DateTime.truncate(:second)
      })

    conn = post(conn, "/api/v1/products/#{product.id}/unarchive", %{})

    assert %{
             "data" => %{
               "product" => %{
                 "status" => "sold",
                 "archived_at" => nil,
                 "sold_at" => sold_at
               }
             }
           } = json_response(conn, 200)

    assert is_binary(sold_at)
  end

  test "GET /api/v1/products/:id includes description_draft when generated copy exists", %{
    conn: conn,
    user: user
  } do
    product = product_fixture(user, %{"title" => "Seller product"})

    assert {:ok, _draft} =
             AI.upsert_product_description_draft(product, %{
               provider: :gemini,
               model: "gemini-description",
               output: %{
                 "suggested_title" => "Generated seller product title",
                 "short_description" => "Generated seller product short description",
                 "long_description" => "Generated seller product long description",
                 "key_features" => ["Feature A"],
                 "seo_keywords" => ["seller-product"]
               }
             })

    conn = get(conn, "/api/v1/products/#{product.id}")

    assert %{
             "data" => %{
               "product" => %{
                 "title" => "Seller product",
                 "description_draft" => %{
                   "status" => "generated",
                   "provider" => "gemini",
                   "model" => "gemini-description",
                   "suggested_title" => "Generated seller product title",
                   "short_description" => "Generated seller product short description",
                   "key_features" => ["Feature A"],
                   "seo_keywords" => ["seller-product"]
                 }
               }
             }
           } = json_response(conn, 200)
  end

  test "GET /api/v1/products/:id includes price_research when pricing exists", %{
    conn: conn,
    user: user
  } do
    product = product_fixture(user, %{"title" => "Seller product"})

    assert {:ok, _price_research} =
             AI.upsert_product_price_research(product, %{
               provider: :gemini,
               model: "gemini-pricing",
               output: %{
                 "currency" => "USD",
                 "suggested_min_price" => 100,
                 "suggested_target_price" => 120,
                 "suggested_max_price" => 140,
                 "suggested_median_price" => 122,
                 "pricing_confidence" => 0.79,
                 "rationale_summary" => "Comparable listings cluster around 120 dollars.",
                 "market_signals" => ["Strong demand", "Fast sell-through"],
                 "comparable_results" => [%{"title" => "Comparable item", "price" => 119.0}]
               }
             })

    conn = get(conn, "/api/v1/products/#{product.id}")

    assert %{
             "data" => %{
               "product" => %{
                 "price_research" => %{
                   "status" => "generated",
                   "provider" => "gemini",
                   "model" => "gemini-pricing",
                   "currency" => "USD",
                   "suggested_target_price" => "120.00",
                   "suggested_median_price" => "122.00",
                   "pricing_confidence" => 0.79,
                   "market_signals" => ["Strong demand", "Fast sell-through"],
                   "comparable_results" => [%{"title" => "Comparable item", "price" => 119.0}]
                 }
               }
             }
           } = json_response(conn, 200)
  end

  test "GET /api/v1/products/:id includes marketplace_listings when generated", %{
    conn: conn,
    user: user
  } do
    product = product_fixture(user, %{"title" => "Seller product"})

    assert {:ok, _listing} =
             Reseller.Marketplaces.upsert_marketplace_listing(product, "ebay", %{
               provider: :gemini,
               model: "gemini-marketplace",
               output: %{
                 "generated_title" => "Generated eBay title",
                 "generated_description" => "Generated eBay description",
                 "generated_tags" => ["ebay", "reseller"],
                 "generated_price_suggestion" => 120,
                 "generation_version" => "gemini-marketplace-v1",
                 "compliance_warnings" => []
               }
             })

    conn = get(conn, "/api/v1/products/#{product.id}")

    assert %{
             "data" => %{
               "product" => %{
                 "marketplace_listings" => [
                   %{
                     "marketplace" => "ebay",
                     "status" => "generated",
                     "generated_title" => "Generated eBay title",
                     "generated_tags" => ["ebay", "reseller"],
                     "generated_price_suggestion" => "120.00"
                   }
                 ]
               }
             }
           } = json_response(conn, 200)
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
                 "latest_processing_run" => %{
                   "status" => "completed",
                   "step" => "awaiting_ai"
                 },
                 "images" => [
                   %{
                     "id" => image_id,
                     "processing_status" => "processing",
                     "checksum" => "abc123",
                     "width" => 1200,
                     "height" => 1600
                   }
                 ]
               },
               "finalized_images" => [%{"id" => finalized_id, "processing_status" => "uploaded"}],
               "processing_run" => %{"status" => "completed", "step" => "awaiting_ai"}
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
