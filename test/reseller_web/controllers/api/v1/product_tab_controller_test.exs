defmodule ResellerWeb.API.V1.ProductTabControllerTest do
  use ResellerWeb.ConnCase, async: true

  setup %{conn: conn} do
    user = user_fixture(%{"email" => "tabs-api@example.com"})
    {raw_token, _api_token} = api_token_fixture(user, %{"device_name" => "iPhone"})

    authed_conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")

    %{conn: authed_conn, user: user}
  end

  test "GET /api/v1/product_tabs lists only the current user's tabs", %{conn: conn, user: user} do
    first_tab = product_tab_fixture(user, %{"name" => "Shoes"})
    second_tab = product_tab_fixture(user, %{"name" => "Outerwear"})
    other_user = user_fixture(%{"email" => "other-tabs@example.com"})
    _other_tab = product_tab_fixture(other_user, %{"name" => "Other"})

    conn = get(conn, "/api/v1/product_tabs")

    assert %{
             "data" => %{
               "product_tabs" => [
                 %{"id" => first_id, "name" => "Shoes", "position" => 1},
                 %{"id" => second_id, "name" => "Outerwear", "position" => 2}
               ]
             }
           } = json_response(conn, 200)

    assert first_id == first_tab.id
    assert second_id == second_tab.id
  end

  test "POST /api/v1/product_tabs creates a seller-defined tab", %{conn: conn} do
    conn =
      post(conn, "/api/v1/product_tabs", %{
        "product_tab" => %{"name" => "Vintage"}
      })

    assert %{
             "data" => %{
               "product_tab" => %{"name" => "Vintage", "position" => 1}
             }
           } = json_response(conn, 201)
  end

  test "PATCH /api/v1/product_tabs/:id updates an owned tab", %{conn: conn, user: user} do
    product_tab = product_tab_fixture(user, %{"name" => "Shoes"})

    conn =
      patch(conn, "/api/v1/product_tabs/#{product_tab.id}", %{
        "product_tab" => %{"name" => "Sneakers"}
      })

    assert %{
             "data" => %{
               "product_tab" => %{"id" => product_tab_id, "name" => "Sneakers", "position" => 1}
             }
           } = json_response(conn, 200)

    assert product_tab_id == product_tab.id
  end

  test "PATCH /api/v1/product_tabs/:id returns not found for another user's tab", %{conn: conn} do
    other_user = user_fixture(%{"email" => "other-owned-tab@example.com"})
    product_tab = product_tab_fixture(other_user, %{"name" => "Other"})

    conn =
      patch(conn, "/api/v1/product_tabs/#{product_tab.id}", %{
        "product_tab" => %{"name" => "Nope"}
      })

    assert json_response(conn, 404) == %{
             "error" => %{
               "code" => "not_found",
               "detail" => "Product tab not found",
               "status" => 404
             }
           }
  end
end
