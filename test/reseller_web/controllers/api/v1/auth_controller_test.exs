defmodule ResellerWeb.API.V1.AuthControllerTest do
  use ResellerWeb.ConnCase, async: true

  alias Reseller.Accounts
  alias Reseller.Accounts.ApiToken
  alias Reseller.Repo

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
                 "supported_marketplaces" => supported_marketplaces,
                 "token" => token,
                 "token_type" => "Bearer",
                 "user" => %{
                   "email" => "seller@example.com",
                   "id" => user_id,
                   "confirmed_at" => nil,
                   "selected_marketplaces" => ["ebay", "depop", "poshmark"]
                 }
               }
             } = json_response(conn, 200)

      assert is_binary(token)
      assert is_binary(expires_at)
      assert is_integer(user_id)
      assert Enum.any?(supported_marketplaces, &(&1["id"] == "mercari"))

      api_token = Repo.get_by!(ApiToken, user_id: user_id)
      assert api_token.context == "mobile"
      assert api_token.device_name == "iPhone"
      assert expires_at == DateTime.to_iso8601(api_token.expires_at)

      {:ok, parsed_expires_at, 0} = DateTime.from_iso8601(expires_at)
      assert DateTime.diff(parsed_expires_at, DateTime.utc_now(), :day) >= 364
    end

    test "ignores admin privilege escalation fields", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          "email" => "seller@example.com",
          "password" => "very-secure-password",
          "is_admin" => true
        })

      assert %{
               "data" => %{
                 "user" => %{
                   "email" => "seller@example.com",
                   "id" => user_id,
                   "selected_marketplaces" => ["ebay", "depop", "poshmark"]
                 }
               }
             } =
               json_response(conn, 200)

      refute Accounts.get_user!(user_id).is_admin
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
                 "supported_marketplaces" => supported_marketplaces,
                 "user" => %{
                   "email" => "seller@example.com",
                   "selected_marketplaces" => ["ebay", "depop", "poshmark"]
                 }
               }
             } = json_response(conn, 200)

      assert is_binary(token)
      assert Enum.any?(supported_marketplaces, &(&1["id"] == "etsy"))

      api_token =
        Repo.get_by!(ApiToken, user_id: Accounts.get_user_by_email("seller@example.com").id)

      assert DateTime.diff(api_token.expires_at, DateTime.utc_now(), :day) >= 364
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

    test "returns bad request when params are incomplete", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/login", %{"email" => "seller@example.com"})

      assert json_response(conn, 400) == %{
               "error" => %{
                 "code" => "invalid_request",
                 "detail" => "Email and password are required",
                 "status" => 400
               }
             }
    end
  end
end
