defmodule ResellerWeb.API.V1.StorefrontControllerTest do
  use ResellerWeb.ConnCase, async: true

  import Reseller.StorefrontFixtures

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

  describe "DELETE /api/v1/storefront/assets/:kind" do
    test "returns 404 when no asset exists", %{conn: conn} do
      conn = delete(conn, "/api/v1/storefront/assets/logo")
      assert json_response(conn, 404)
    end
  end
end
