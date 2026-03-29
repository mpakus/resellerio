defmodule ResellerWeb.API.V1.RootControllerTest do
  use ResellerWeb.ConnCase, async: true

  test "returns api metadata and endpoint index", %{conn: conn} do
    conn = get(conn, "/api/v1")

    assert json_response(conn, 200) == %{
             "data" => %{
               "docs_path" => "/docs/API.md",
               "endpoints" => [
                 %{
                   "description" =>
                     "Returns API metadata and the list of currently available endpoints.",
                   "method" => "GET",
                   "path" => "/api/v1"
                 },
                 %{
                   "description" => "Returns service health and application version information.",
                   "method" => "GET",
                   "path" => "/api/v1/health"
                 },
                 %{
                   "description" => "Lists products for the authenticated user.",
                   "method" => "GET",
                   "path" => "/api/v1/products"
                 },
                 %{
                   "description" =>
                     "Creates a product and optionally returns signed upload instructions.",
                   "method" => "POST",
                   "path" => "/api/v1/products"
                 },
                 %{
                   "description" => "Returns one product for the authenticated user.",
                   "method" => "GET",
                   "path" => "/api/v1/products/:id"
                 },
                 %{
                   "description" => "Marks uploaded product images as ready for processing.",
                   "method" => "POST",
                   "path" => "/api/v1/products/:id/finalize_uploads"
                 }
               ],
               "name" => "reseller",
               "version" => "v1"
             }
           }
  end
end
