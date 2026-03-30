defmodule ResellerWeb.API.V1.HealthControllerTest do
  use ResellerWeb.ConnCase, async: true

  test "returns api health payload", %{conn: conn} do
    conn = get(conn, "/api/v1/health")

    assert json_response(conn, 200) == %{
             "data" => %{
               "name" => "resellerio",
               "status" => "ok",
               "version" => "0.1.0"
             }
           }
  end

  test "renders stable json error payload for missing api routes", %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/missing")

    assert json_response(conn, 404) == %{
             "error" => %{
               "code" => "not_found",
               "detail" => "Not Found",
               "status" => 404
             }
           }
  end
end
