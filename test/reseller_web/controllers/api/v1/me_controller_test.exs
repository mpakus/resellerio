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
               "supported_marketplaces" => [
                 %{"id" => "ebay", "label" => "eBay"},
                 %{"id" => "depop", "label" => "Depop"},
                 %{"id" => "poshmark", "label" => "Poshmark"},
                 %{"id" => "mercari", "label" => "Mercari"},
                 %{"id" => "facebook_marketplace", "label" => "Facebook Marketplace"},
                 %{"id" => "offerup", "label" => "OfferUp"},
                 %{"id" => "whatnot", "label" => "Whatnot"},
                 %{"id" => "grailed", "label" => "Grailed"},
                 %{"id" => "therealreal", "label" => "The RealReal"},
                 %{"id" => "vestiaire_collective", "label" => "Vestiaire Collective"},
                 %{"id" => "thredup", "label" => "thredUp"},
                 %{"id" => "etsy", "label" => "Etsy"}
               ],
               "user" => %{
                 "confirmed_at" => nil,
                 "email" => "seller@example.com",
                 "id" => user.id,
                 "selected_marketplaces" => ["ebay", "depop", "poshmark"]
               }
             }
           }
  end

  test "updates the authenticated user's selected marketplaces", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    {:ok, raw_token, _api_token} = Accounts.issue_api_token(user, %{"device_name" => "iPhone"})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")
      |> patch("/api/v1/me", %{
        "user" => %{
          "selected_marketplaces" => ["mercari", "etsy", "ebay"]
        }
      })

    assert %{
             "data" => %{
               "user" => %{
                 "selected_marketplaces" => ["ebay", "mercari", "etsy"]
               }
             }
           } = json_response(conn, 200)

    assert Accounts.get_user!(user.id).selected_marketplaces == ["ebay", "mercari", "etsy"]
  end

  test "returns validation errors for unsupported marketplaces", %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    {:ok, raw_token, _api_token} = Accounts.issue_api_token(user, %{"device_name" => "iPhone"})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")
      |> patch("/api/v1/me", %{
        "user" => %{
          "selected_marketplaces" => ["mercari", "unknown_market"]
        }
      })

    assert json_response(conn, 422) == %{
             "error" => %{
               "code" => "validation_failed",
               "detail" => "Validation failed",
               "fields" => %{
                 "selected_marketplaces" => [
                   "contains unsupported marketplaces: unknown_market"
                 ]
               },
               "status" => 422
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
