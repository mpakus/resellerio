defmodule ResellerWeb.API.V1.RootControllerTest do
  use ResellerWeb.ConnCase, async: true

  test "returns api metadata and endpoint index", %{conn: conn} do
    conn = get(conn, "/api/v1")
    body = json_response(conn, 200)

    assert body["data"]["name"] == "resellerio"
    assert body["data"]["version"] == "v1"
    assert body["data"]["docs_path"] == "/docs/API.md"

    endpoints = body["data"]["endpoints"]
    paths = Enum.map(endpoints, & &1["path"])

    assert "/api/v1" in paths
    assert "/api/v1/health" in paths
    assert "/api/v1/auth/register" in paths
    assert "/api/v1/auth/login" in paths
    assert "/api/v1/me" in paths
    assert "/api/v1/product_tabs" in paths
    assert "/api/v1/product_tabs/:id" in paths
    assert "/api/v1/storefront" in paths
    assert "/api/v1/storefront/pages" in paths
    assert "/api/v1/storefront/pages/:page_id" in paths
    assert "/api/v1/storefront/assets/:kind" in paths
    assert "/api/v1/inquiries" in paths
    assert "/api/v1/inquiries/:id" in paths
    assert "/api/v1/products" in paths
    assert "/api/v1/products/:id" in paths
    assert "/api/v1/products/:id/finalize_uploads" in paths
    assert "/api/v1/products/:id/reprocess" in paths
    assert "/api/v1/products/:id/generate_lifestyle_images" in paths
    assert "/api/v1/products/:id/generated_images/:image_id/approve" in paths
    assert "/api/v1/products/:id/generated_images/:image_id" in paths
    assert "/api/v1/products/:id/images/:image_id" in paths
    assert "/api/v1/products/:id/mark_sold" in paths
    assert "/api/v1/products/:id/archive" in paths
    assert "/api/v1/products/:id/unarchive" in paths
    assert "/api/v1/exports" in paths
    assert "/api/v1/exports/:id" in paths
    assert "/api/v1/imports" in paths
    assert "/api/v1/imports/:id" in paths
  end
end
