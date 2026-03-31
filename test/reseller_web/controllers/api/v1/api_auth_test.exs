defmodule ResellerWeb.API.V1.APIAuthTest do
  use ResellerWeb.ConnCase, async: true

  alias Reseller.Accounts.ApiToken
  alias Reseller.Repo

  @unauthorized_error %{
    "error" => %{
      "code" => "unauthorized",
      "detail" => "Missing or invalid bearer token",
      "status" => 401
    }
  }

  test "representative protected routes reject missing bearer tokens" do
    requests = [
      {:get, "/api/v1/product_tabs", nil},
      {:get, "/api/v1/products", nil},
      {:post, "/api/v1/exports", %{}},
      {:post, "/api/v1/imports", %{"import" => %{"filename" => "catalog.zip"}}}
    ]

    Enum.each(requests, fn {method, path, params} ->
      conn = request(build_conn(), method, path, params)
      assert json_response(conn, 401) == @unauthorized_error
    end)
  end

  test "protected routes reject expired bearer tokens", %{conn: conn} do
    user = user_fixture(%{"email" => "expired-products@example.com"})
    {raw_token, _api_token} = expired_api_token_fixture(user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")
      |> get("/api/v1/products")

    assert json_response(conn, 401) == @unauthorized_error
  end

  test "protected routes reject malformed bearer headers", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", "Token no-bearer-prefix")
      |> get("/api/v1/products")

    assert json_response(conn, 401) == @unauthorized_error
  end

  test "protected routes accept case-insensitive bearer auth and touch last_used_at", %{
    conn: conn
  } do
    user = user_fixture(%{"email" => "mobile-auth@example.com"})
    {raw_token, api_token} = api_token_fixture(user, %{"device_name" => "Android"})

    assert is_nil(api_token.last_used_at)

    conn =
      conn
      |> put_req_header("authorization", "bearer #{raw_token}")
      |> get("/api/v1/products")

    assert %{"data" => %{"products" => []}} = json_response(conn, 200)
    assert %ApiToken{last_used_at: %DateTime{}} = Repo.get!(ApiToken, api_token.id)
  end

  defp request(conn, :get, path, _params), do: get(conn, path)
  defp request(conn, :post, path, params), do: post(conn, path, params || %{})
end
