defmodule ResellerWeb.API.V1.OpenAPIControllerTest do
  use ResellerWeb.ConnCase, async: true

  test "returns an OpenAPI document for the current API version", %{conn: conn} do
    conn = get(conn, "/api/v1/openapi.json")
    body = json_response(conn, 200)

    assert body["openapi"] == "3.1.0"
    assert body["info"]["title"] == "ResellerIO API"
    assert body["info"]["version"] == "v1"
    assert body["externalDocs"]["url"] == "/docs/api"

    assert get_in(body, ["components", "securitySchemes", "BearerAuth", "scheme"]) == "bearer"

    assert get_in(body, ["paths", "/api/v1/openapi.json", "get", "summary"]) ==
             "Get OpenAPI document"

    assert get_in(body, ["paths", "/api/v1/me/usage", "get", "security"]) == [
             %{"BearerAuth" => []}
           ]

    assert get_in(body, ["paths", "/api/v1/me/usage", "get", "tags"]) == ["User"]

    assert get_in(body, ["paths", "/api/v1/products/{id}", "get", "parameters"]) == [
             %{
               "description" => "Primary resource identifier.",
               "in" => "path",
               "name" => "id",
               "required" => true,
               "schema" => %{"type" => "string"}
             }
           ]

    assert get_in(body, ["paths", "/api/v1/products", "get", "parameters"])
           |> Enum.any?(fn param ->
             param["name"] == "page" and param["in"] == "query"
           end)
  end
end
