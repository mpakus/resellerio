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
                 }
               ],
               "name" => "reseller",
               "version" => "v1"
             }
           }
  end
end
