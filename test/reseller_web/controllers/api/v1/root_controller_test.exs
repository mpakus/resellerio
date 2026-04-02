defmodule ResellerWeb.API.V1.RootControllerTest do
  use ResellerWeb.ConnCase, async: true

  test "returns api metadata and endpoint index", %{conn: conn} do
    conn = get(conn, "/api/v1")
    body = json_response(conn, 200)

    assert body["data"]["name"] == "resellerio"
    assert body["data"]["version"] == "v1"
    assert body["data"]["docs_path"] == "/docs/API.md"
    assert body["data"]["docs_ui_path"] == "/docs/api"
    assert body["data"]["openapi_path"] == "/api/v1/openapi.json"

    endpoints = body["data"]["endpoints"]
    method_paths = MapSet.new(Enum.map(endpoints, &{&1["method"], &1["path"]}))

    assert {"GET", "/api/v1"} in method_paths
    assert {"GET", "/api/v1/openapi.json"} in method_paths
    assert {"GET", "/api/v1/health"} in method_paths
    assert {"POST", "/api/v1/auth/register"} in method_paths
    assert {"POST", "/api/v1/auth/login"} in method_paths
    assert {"GET", "/api/v1/me"} in method_paths
    assert {"PATCH", "/api/v1/me"} in method_paths
    assert {"GET", "/api/v1/me/usage"} in method_paths
    assert {"GET", "/api/v1/product_tabs"} in method_paths
    assert {"POST", "/api/v1/product_tabs"} in method_paths
    assert {"PATCH", "/api/v1/product_tabs/:id"} in method_paths
    assert {"DELETE", "/api/v1/product_tabs/:id"} in method_paths
    assert {"GET", "/api/v1/storefront"} in method_paths
    assert {"PUT", "/api/v1/storefront"} in method_paths
    assert {"GET", "/api/v1/storefront/pages"} in method_paths
    assert {"POST", "/api/v1/storefront/pages"} in method_paths
    assert {"PATCH", "/api/v1/storefront/pages/:page_id"} in method_paths
    assert {"DELETE", "/api/v1/storefront/pages/:page_id"} in method_paths
    assert {"PUT", "/api/v1/storefront/pages/order"} in method_paths
    assert {"POST", "/api/v1/storefront/assets/:kind/prepare_upload"} in method_paths
    assert {"DELETE", "/api/v1/storefront/assets/:kind"} in method_paths
    assert {"GET", "/api/v1/inquiries"} in method_paths
    assert {"DELETE", "/api/v1/inquiries/:id"} in method_paths
    assert {"GET", "/api/v1/products"} in method_paths
    assert {"POST", "/api/v1/products"} in method_paths
    assert {"GET", "/api/v1/products/:id"} in method_paths
    assert {"PATCH", "/api/v1/products/:id"} in method_paths
    assert {"DELETE", "/api/v1/products/:id"} in method_paths
    assert {"POST", "/api/v1/products/:id/prepare_uploads"} in method_paths
    assert {"POST", "/api/v1/products/:id/finalize_uploads"} in method_paths
    assert {"POST", "/api/v1/products/:id/reprocess"} in method_paths
    assert {"POST", "/api/v1/products/:id/generate_lifestyle_images"} in method_paths
    assert {"GET", "/api/v1/products/:id/lifestyle_generation_runs"} in method_paths
    assert {"POST", "/api/v1/products/:id/generated_images/:image_id/approve"} in method_paths
    assert {"DELETE", "/api/v1/products/:id/generated_images/:image_id"} in method_paths
    assert {"DELETE", "/api/v1/products/:id/images/:image_id"} in method_paths
    assert {"PATCH", "/api/v1/products/:id/images/:image_id/storefront"} in method_paths
    assert {"PUT", "/api/v1/products/:id/images/storefront_order"} in method_paths
    assert {"POST", "/api/v1/products/:id/mark_sold"} in method_paths
    assert {"POST", "/api/v1/products/:id/archive"} in method_paths
    assert {"POST", "/api/v1/products/:id/unarchive"} in method_paths
    assert {"POST", "/api/v1/exports"} in method_paths
    assert {"GET", "/api/v1/exports/:id"} in method_paths
    assert {"POST", "/api/v1/imports"} in method_paths
    assert {"GET", "/api/v1/imports/:id"} in method_paths
  end
end
