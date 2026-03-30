defmodule ResellerWeb.API.V1.ExportControllerTest do
  use ResellerWeb.ConnCase, async: true

  setup %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    {raw_token, _api_token} = api_token_fixture(user, %{"device_name" => "iPhone"})

    authed_conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")

    %{conn: authed_conn, user: user}
  end

  test "POST /api/v1/exports queues and completes an export", %{conn: conn, user: user} do
    product_fixture(user, %{"title" => "Export product"})

    conn =
      post(conn, "/api/v1/exports", %{
        "download_request_fun" => "ignored"
      })

    assert %{
             "data" => %{
               "export" => %{
                 "status" => "completed",
                 "storage_key" => storage_key,
                 "download_url" => download_url
               }
             }
           } = json_response(conn, 202)

    assert storage_key =~ "users/#{user.id}/exports/"
    assert download_url =~ storage_key
  end

  test "GET /api/v1/exports/:id returns not found for another user's export", %{conn: conn} do
    other_user = user_fixture(%{"email" => "other@example.com"})
    product_fixture(other_user, %{"title" => "Other product"})

    {:ok, export} =
      Reseller.Exports.request_export_for_user(other_user,
        download_request_fun: fn _image_url -> {:ok, %{status: 200, body: "binary"}} end,
        public_base_url: "https://cdn.example.test"
      )

    conn = get(conn, "/api/v1/exports/#{export.id}")

    assert json_response(conn, 404) == %{
             "error" => %{
               "code" => "not_found",
               "detail" => "Export not found",
               "status" => 404
             }
           }
  end
end
