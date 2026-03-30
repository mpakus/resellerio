defmodule ResellerWeb.Security.PenetrationTest do
  use ResellerWeb.ConnCase, async: true

  describe "privilege escalation attempts" do
    test "public api registration cannot create an admin account", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          "email" => "attacker@example.com",
          "password" => "very-secure-password",
          "is_admin" => true
        })

      assert %{"data" => %{"user" => %{"id" => user_id}}} = json_response(conn, 200)
      refute Reseller.Accounts.get_user!(user_id).is_admin
    end

    test "browser sign-up cannot create an admin account", %{conn: conn} do
      conn =
        post(conn, "/sign-up", %{
          "user" => %{
            "email" => "attacker@example.com",
            "password" => "very-secure-password",
            "is_admin" => true
          }
        })

      user_id = get_session(conn, :user_id)

      assert redirected_to(conn) == "/app"
      refute Reseller.Accounts.get_user!(user_id).is_admin
    end
  end

  describe "admin boundary checks" do
    test "non-admin users cannot open admin resources", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> init_test_session(%{user_id: user.id})
        |> get("/admin/users/")

      assert redirected_to(conn) == "/app"
    end

    test "unauthenticated users cannot open admin resources", %{conn: conn} do
      conn = get(conn, "/admin/api-tokens/")

      assert redirected_to(conn) == "/sign-in"
    end
  end

  describe "api token abuse" do
    test "expired bearer tokens are rejected", %{conn: conn} do
      user = user_fixture()
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
  end

  describe "product lifecycle ownership checks" do
    test "authenticated users cannot mutate another user's products", %{conn: conn} do
      attacker = user_fixture(%{"email" => "attacker@example.com"})
      owner = user_fixture(%{"email" => "owner@example.com"})
      {raw_token, _api_token} = api_token_fixture(attacker, %{"device_name" => "Attacker phone"})
      product = product_fixture(owner, %{"title" => "Protected product", "status" => "ready"})

      authed_conn = put_req_header(conn, "authorization", "Bearer #{raw_token}")

      Enum.each(
        [
          {:patch, "/api/v1/products/#{product.id}", %{"product" => %{"title" => "Pwned"}}},
          {:delete, "/api/v1/products/#{product.id}", %{}},
          {:post, "/api/v1/products/#{product.id}/mark_sold", %{}},
          {:post, "/api/v1/products/#{product.id}/archive", %{}},
          {:post, "/api/v1/products/#{product.id}/unarchive", %{}}
        ],
        fn
          {:patch, path, params} ->
            response = patch(authed_conn, path, params)
            assert json_response(response, 404)["error"]["code"] == "not_found"

          {:delete, path, _params} ->
            response = delete(authed_conn, path)
            assert json_response(response, 404)["error"]["code"] == "not_found"

          {:post, path, params} ->
            response = post(authed_conn, path, params)
            assert json_response(response, 404)["error"]["code"] == "not_found"
        end
      )
    end
  end
end
