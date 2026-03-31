defmodule ResellerWeb.API.V1.ExportControllerTest do
  use ResellerWeb.ConnCase, async: true

  import Ecto.Query

  alias Reseller.Exports.Export
  alias Reseller.Repo

  setup %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    {raw_token, _api_token} = api_token_fixture(user, %{"device_name" => "iPhone"})

    authed_conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")

    %{conn: authed_conn, user: user}
  end

  test "POST /api/v1/exports queues and completes an export", %{conn: conn, user: user} do
    product_fixture(user, %{"title" => "Fila jacket", "status" => "ready"})
    product_fixture(user, %{"title" => "Canvas tote", "status" => "ready"})

    conn =
      post(conn, "/api/v1/exports", %{
        "export" => %{
          "name" => "Fila export",
          "filters" => %{"query" => "Fila"}
        }
      })

    assert %{
             "data" => %{
               "export" => %{
                 "name" => "Fila export",
                 "file_name" => file_name,
                 "filter_params" => %{"query" => "Fila"},
                 "product_count" => 1,
                 "status" => "completed",
                 "storage_key" => storage_key,
                 "download_url" => download_url
               }
             }
           } = json_response(conn, 202)

    assert file_name =~ "fila-export-"
    assert storage_key =~ "users/#{user.id}/exports/"
    assert storage_key =~ "/" <> file_name
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

  test "GET /api/v1/exports/:id reclassifies stale running exports as stalled", %{
    conn: conn,
    user: user
  } do
    stale_time = ~U[2026-03-31 05:00:00Z]

    export =
      %Export{}
      |> Export.create_changeset(%{
        "name" => "Stale export",
        "file_name" => "stale-export.zip",
        "filter_params" => %{},
        "product_count" => 3,
        "status" => "running",
        "requested_at" => stale_time
      })
      |> Ecto.Changeset.put_assoc(:user, user)
      |> Repo.insert!()

    from(record in Export, where: record.id == ^export.id)
    |> Repo.update_all(set: [updated_at: stale_time])

    conn = get(conn, "/api/v1/exports/#{export.id}")

    assert %{
             "data" => %{
               "export" => %{
                 "id" => export_id,
                 "status" => "stalled",
                 "error_message" => error_message
               }
             }
           } = json_response(conn, 200)

    assert export_id == export.id

    assert error_message ==
             "Export has been running for more than 10 minutes without finishing. It was marked as stalled."
  end
end
