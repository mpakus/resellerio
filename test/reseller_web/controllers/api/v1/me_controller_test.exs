defmodule ResellerWeb.API.V1.MeControllerTest do
  use ResellerWeb.ConnCase, async: true

  alias Reseller.Accounts

  test "returns the authenticated user", %{conn: conn} do
    assert {:ok, user} =
             Accounts.register_user(%{
               "email" => "seller@example.com",
               "password" => "very-secure-password"
             })

    assert {:ok, raw_token, _api_token} =
             Accounts.issue_api_token(user, %{"device_name" => "iPhone"})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")
      |> get("/api/v1/me")

    assert json_response(conn, 200) == %{
             "data" => %{
               "user" => %{
                 "confirmed_at" => nil,
                 "email" => "seller@example.com",
                 "id" => user.id
               }
             }
           }
  end

  test "returns unauthorized when the bearer token is missing", %{conn: conn} do
    conn = get(conn, "/api/v1/me")

    assert json_response(conn, 401) == %{
             "error" => %{
               "code" => "unauthorized",
               "detail" => "Missing or invalid bearer token",
               "status" => 401
             }
           }
  end

  test "returns unauthorized when the bearer token is expired", %{conn: conn} do
    user = user_fixture(%{"email" => "expired@example.com"})
    {raw_token, _api_token} = expired_api_token_fixture(user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")
      |> get("/api/v1/me")

    assert json_response(conn, 401) == %{
             "error" => %{
               "code" => "unauthorized",
               "detail" => "Missing or invalid bearer token",
               "status" => 401
             }
           }
  end

  test "returns unauthorized for malformed authorization headers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Token no-bearer-prefix")
      |> get("/api/v1/me")

    assert json_response(conn, 401) == %{
             "error" => %{
               "code" => "unauthorized",
               "detail" => "Missing or invalid bearer token",
               "status" => 401
             }
           }
  end
end
