defmodule ResellerWeb.API.V1.StorefrontControllerTest do
  use ResellerWeb.ConnCase, async: true

  import Reseller.StorefrontFixtures

  alias Reseller.Media
  alias Reseller.Storefronts

  setup %{conn: conn} do
    user = user_fixture(%{"email" => "storefront-api@example.com"})
    {raw_token, _api_token} = api_token_fixture(user, %{"device_name" => "iPhone"})

    authed_conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")

    %{conn: authed_conn, user: user}
  end

  describe "GET /api/v1/storefront" do
    test "returns an empty storefront when none exists", %{conn: conn} do
      conn = get(conn, "/api/v1/storefront")
      body = json_response(conn, 200)

      assert body["data"]["storefront"]["id"] == nil
      assert body["data"]["storefront"]["slug"] == nil
    end

    test "returns the storefront when one exists", %{conn: conn, user: user} do
      storefront = storefront_fixture(user, %{"slug" => "mystore", "title" => "My Store"})

      conn = get(conn, "/api/v1/storefront")
      body = json_response(conn, 200)

      assert body["data"]["storefront"]["id"] == storefront.id
      assert body["data"]["storefront"]["slug"] == "mystore"
      assert body["data"]["storefront"]["title"] == "My Store"
    end

    test "returns storefront asset urls", %{conn: conn, user: user} do
      storefront = storefront_fixture(user, %{"slug" => "mystore", "title" => "My Store"})

      {:ok, _logo} =
        Storefronts.upsert_storefront_asset_for_user(user, "logo", %{
          "storage_key" => "users/#{user.id}/storefronts/#{storefront.id}/logo/logo.png",
          "content_type" => "image/png",
          "original_filename" => "logo.png",
          "width" => 400,
          "height" => 400,
          "byte_size" => 45_000
        })

      {:ok, _header} =
        Storefronts.upsert_storefront_asset_for_user(user, "header", %{
          "storage_key" => "users/#{user.id}/storefronts/#{storefront.id}/header/header.jpg",
          "content_type" => "image/jpeg",
          "original_filename" => "header.jpg",
          "width" => 1800,
          "height" => 600,
          "byte_size" => 54_000
        })

      header_storage_key = "users/#{user.id}/storefronts/#{storefront.id}/header/header.jpg"
      logo_storage_key = "users/#{user.id}/storefronts/#{storefront.id}/logo/logo.png"

      header_url = Media.public_url_for_storage_key!(header_storage_key)
      logo_url = Media.public_url_for_storage_key!(logo_storage_key)

      conn = get(conn, "/api/v1/storefront")

      assert %{
               "data" => %{
                 "storefront" => %{
                   "image_urls" => [^header_url, ^logo_url],
                   "assets" => [
                     %{"kind" => "header", "url" => ^header_url},
                     %{"kind" => "logo", "url" => ^logo_url}
                   ]
                 }
               }
             } = json_response(conn, 200)
    end

    test "returns 401 when unauthenticated" do
      conn = build_conn()
      conn = get(conn, "/api/v1/storefront")
      assert json_response(conn, 401)
    end
  end

  describe "PUT /api/v1/storefront" do
    test "creates a storefront", %{conn: conn} do
      conn =
        put(conn, "/api/v1/storefront", %{
          "storefront" => %{"slug" => "new-store", "title" => "New Store", "enabled" => false}
        })

      body = json_response(conn, 200)
      assert body["data"]["storefront"]["slug"] == "new-store"
      assert body["data"]["storefront"]["title"] == "New Store"
    end

    test "updates an existing storefront", %{conn: conn, user: user} do
      storefront_fixture(user, %{"slug" => "old-slug", "title" => "Old"})

      conn =
        put(conn, "/api/v1/storefront", %{
          "storefront" => %{"slug" => "old-slug", "title" => "Updated"}
        })

      body = json_response(conn, 200)
      assert body["data"]["storefront"]["title"] == "Updated"
    end

    test "returns 422 for invalid params", %{conn: conn} do
      conn =
        put(conn, "/api/v1/storefront", %{
          "storefront" => %{"slug" => ""}
        })

      assert json_response(conn, 422)
    end

    test "returns 401 when unauthenticated" do
      conn = build_conn()
      conn = put(conn, "/api/v1/storefront", %{"storefront" => %{}})
      assert json_response(conn, 401)
    end
  end

  describe "GET /api/v1/storefront/pages" do
    test "returns empty list when no pages exist", %{conn: conn} do
      conn = get(conn, "/api/v1/storefront/pages")
      body = json_response(conn, 200)
      assert body["data"]["pages"] == []
    end

    test "returns pages for the current user", %{conn: conn, user: user} do
      page = storefront_page_fixture(user, %{"title" => "About"})

      conn = get(conn, "/api/v1/storefront/pages")
      body = json_response(conn, 200)

      assert length(body["data"]["pages"]) == 1
      assert hd(body["data"]["pages"])["id"] == page.id
      assert hd(body["data"]["pages"])["title"] == "About"
    end
  end

  describe "POST /api/v1/storefront/pages" do
    test "creates a page when storefront exists", %{conn: conn, user: user} do
      storefront_fixture(user, %{"slug" => "my-store"})

      conn =
        post(conn, "/api/v1/storefront/pages", %{
          "page" => %{"title" => "Returns", "body" => "Returns policy here."}
        })

      body = json_response(conn, 201)
      assert body["data"]["page"]["title"] == "Returns"
    end

    test "returns 422 when no storefront exists", %{conn: conn} do
      conn =
        post(conn, "/api/v1/storefront/pages", %{
          "page" => %{"title" => "About", "body" => "Body."}
        })

      assert %{"error" => %{"code" => "storefront_not_found"}} = json_response(conn, 422)
    end
  end

  describe "PATCH /api/v1/storefront/pages/:page_id" do
    test "updates an owned page", %{conn: conn, user: user} do
      page = storefront_page_fixture(user, %{"title" => "About"})

      conn =
        patch(conn, "/api/v1/storefront/pages/#{page.id}", %{
          "page" => %{"title" => "About Us"}
        })

      body = json_response(conn, 200)
      assert body["data"]["page"]["title"] == "About Us"
    end

    test "returns 404 for another user's page", %{conn: conn} do
      other_user = user_fixture(%{"email" => "other-sf-page@example.com"})
      page = storefront_page_fixture(other_user, %{"title" => "Other"})

      conn =
        patch(conn, "/api/v1/storefront/pages/#{page.id}", %{
          "page" => %{"title" => "Nope"}
        })

      assert json_response(conn, 404)
    end
  end

  describe "DELETE /api/v1/storefront/pages/:page_id" do
    test "deletes an owned page", %{conn: conn, user: user} do
      page = storefront_page_fixture(user, %{"title" => "About"})

      conn = delete(conn, "/api/v1/storefront/pages/#{page.id}")

      assert json_response(conn, 200) == %{"data" => %{"deleted" => true}}
    end

    test "returns 404 for another user's page", %{conn: conn} do
      other_user = user_fixture(%{"email" => "other-del-sf-page@example.com"})
      page = storefront_page_fixture(other_user, %{"title" => "Other"})

      conn = delete(conn, "/api/v1/storefront/pages/#{page.id}")

      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/v1/storefront/pages/order" do
    test "reorders owned pages", %{conn: conn, user: user} do
      first_page = storefront_page_fixture(user, %{"title" => "About"})
      second_page = storefront_page_fixture(user, %{"title" => "Shipping"})

      conn =
        put(conn, "/api/v1/storefront/pages/order", %{
          "page_ids" => [second_page.id, first_page.id]
        })

      assert %{
               "data" => %{
                 "pages" => [
                   %{"id" => returned_first_id, "position" => 1},
                   %{"id" => returned_second_id, "position" => 2}
                 ]
               }
             } = json_response(conn, 200)

      assert returned_first_id == second_page.id
      assert returned_second_id == first_page.id
    end
  end

  describe "POST /api/v1/storefront/assets/:kind/prepare_upload" do
    test "prepares upload instructions for logo and header assets", %{conn: conn, user: user} do
      storefront_fixture(user, %{"slug" => "my-store"})

      logo_conn =
        post(conn, "/api/v1/storefront/assets/logo/prepare_upload", %{
          "asset" => %{
            "filename" => "logo.png",
            "content_type" => "image/png",
            "byte_size" => 12_345,
            "width" => 400,
            "height" => 400
          }
        })

      assert %{
               "data" => %{
                 "asset" => %{
                   "kind" => "logo",
                   "content_type" => "image/png",
                   "original_filename" => "logo.png"
                 },
                 "upload_instruction" => %{
                   "method" => "PUT",
                   "headers" => %{"content-type" => "image/png"},
                   "upload_url" => logo_upload_url
                 }
               }
             } = json_response(logo_conn, 200)

      assert logo_upload_url =~ "https://uploads.example.test/"

      header_conn =
        post(conn, "/api/v1/storefront/assets/header/prepare_upload", %{
          "asset" => %{
            "filename" => "header.jpg",
            "content_type" => "image/jpeg",
            "byte_size" => 54_321,
            "width" => 1800,
            "height" => 600
          }
        })

      assert %{
               "data" => %{
                 "asset" => %{
                   "kind" => "header",
                   "content_type" => "image/jpeg",
                   "original_filename" => "header.jpg"
                 },
                 "upload_instruction" => %{
                   "method" => "PUT",
                   "headers" => %{"content-type" => "image/jpeg"},
                   "upload_url" => header_upload_url
                 }
               }
             } = json_response(header_conn, 200)

      assert header_upload_url =~ "https://uploads.example.test/"
      assert_received {:media_storage_called, _logo_storage_key, _logo_opts}
      assert_received {:media_storage_called, _header_storage_key, _header_opts}
    end

    test "returns 422 when storefront does not exist", %{conn: conn} do
      conn =
        post(conn, "/api/v1/storefront/assets/logo/prepare_upload", %{
          "asset" => %{
            "filename" => "logo.png",
            "content_type" => "image/png"
          }
        })

      assert %{"error" => %{"code" => "storefront_not_found"}} = json_response(conn, 422)
    end
  end

  describe "DELETE /api/v1/storefront/assets/:kind" do
    test "returns 404 when no asset exists", %{conn: conn} do
      conn = delete(conn, "/api/v1/storefront/assets/logo")
      assert json_response(conn, 404)
    end
  end
end
