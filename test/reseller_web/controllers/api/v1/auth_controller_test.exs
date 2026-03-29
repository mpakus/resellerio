defmodule ResellerWeb.API.V1.AuthControllerTest do
  use ResellerWeb.ConnCase, async: true

  alias Reseller.Accounts

  describe "POST /api/v1/auth/register" do
    test "creates a user and returns a bearer token", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          "email" => "seller@example.com",
          "password" => "very-secure-password",
          "device_name" => "iPhone"
        })

      assert %{
               "data" => %{
                 "expires_at" => expires_at,
                 "token" => token,
                 "token_type" => "Bearer",
                 "user" => %{
                   "email" => "seller@example.com",
                   "id" => user_id,
                   "confirmed_at" => nil
                 }
               }
             } = json_response(conn, 200)

      assert is_binary(token)
      assert is_binary(expires_at)
      assert is_integer(user_id)
    end

    test "returns validation errors for invalid params", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          "email" => "bad email",
          "password" => "short"
        })

      assert json_response(conn, 422) == %{
               "error" => %{
                 "code" => "validation_failed",
                 "detail" => "Validation failed",
                 "fields" => %{
                   "email" => ["must have the @ sign and no spaces"],
                   "password" => ["should be at least 12 character(s)"]
                 },
                 "status" => 422
               }
             }
    end
  end

  describe "POST /api/v1/auth/login" do
    test "returns a token for valid credentials", %{conn: conn} do
      assert {:ok, _user} =
               Accounts.register_user(%{
                 "email" => "seller@example.com",
                 "password" => "very-secure-password"
               })

      conn =
        post(conn, "/api/v1/auth/login", %{
          "email" => "seller@example.com",
          "password" => "very-secure-password",
          "device_name" => "Pixel"
        })

      assert %{
               "data" => %{
                 "token" => token,
                 "token_type" => "Bearer",
                 "user" => %{"email" => "seller@example.com"}
               }
             } = json_response(conn, 200)

      assert is_binary(token)
    end

    test "rejects invalid credentials", %{conn: conn} do
      assert {:ok, _user} =
               Accounts.register_user(%{
                 "email" => "seller@example.com",
                 "password" => "very-secure-password"
               })

      conn =
        post(conn, "/api/v1/auth/login", %{
          "email" => "seller@example.com",
          "password" => "wrong-password"
        })

      assert json_response(conn, 401) == %{
               "error" => %{
                 "code" => "unauthorized",
                 "detail" => "Invalid email or password",
                 "status" => 401
               }
             }
    end
  end
end
