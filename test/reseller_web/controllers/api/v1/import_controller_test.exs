defmodule ResellerWeb.API.V1.ImportControllerTest do
  use ResellerWeb.ConnCase, async: true

  setup %{conn: conn} do
    user = user_fixture(%{"email" => "import-api@example.com"})
    {raw_token, _api_token} = api_token_fixture(user, %{"device_name" => "iPhone"})

    authed_conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")

    %{conn: authed_conn, user: user}
  end

  test "POST /api/v1/imports queues and completes an import", %{conn: conn, user: user} do
    zip_binary = build_import_zip(%{"products" => []}, %{})

    conn =
      post(conn, "/api/v1/imports", %{
        "import" => %{
          "filename" => "catalog.zip",
          "archive_base64" => Base.encode64(zip_binary)
        }
      })

    assert %{
             "data" => %{
               "import" => %{
                 "status" => "completed",
                 "source_filename" => "catalog.zip",
                 "source_storage_key" => source_storage_key,
                 "total_products" => 0,
                 "imported_products" => 0,
                 "failed_products" => 0
               }
             }
           } = json_response(conn, 202)

    assert source_storage_key =~ "users/#{user.id}/imports/"
  end

  test "POST /api/v1/imports returns validation errors for invalid base64", %{conn: conn} do
    conn =
      post(conn, "/api/v1/imports", %{
        "import" => %{
          "filename" => "broken.zip",
          "archive_base64" => "%%%not-base64%%%"
        }
      })

    assert json_response(conn, 422) == %{
             "error" => %{
               "code" => "validation_failed",
               "detail" => "Validation failed",
               "fields" => %{"archive_base64" => ["must be valid base64"]},
               "status" => 422
             }
           }
  end

  test "GET /api/v1/imports/:id returns not found for another user's import", %{conn: conn} do
    other_user = user_fixture(%{"email" => "other-import@example.com"})

    {:ok, import_record} =
      Reseller.Imports.request_import_for_user(other_user, %{
        "filename" => "other.zip",
        "archive_base64" => Base.encode64(build_import_zip(%{"products" => []}, %{}))
      })

    conn = get(conn, "/api/v1/imports/#{import_record.id}")

    assert json_response(conn, 404) == %{
             "error" => %{
               "code" => "not_found",
               "detail" => "Import not found",
               "status" => 404
             }
           }
  end

  defp build_import_zip(index_payload, image_entries) do
    entries =
      [
        {~c"manifest.json", Jason.encode!(index_payload, pretty: true)},
        {~c"Products.xls", "<Workbook></Workbook>"}
      ] ++
        Enum.map(image_entries, fn {path, body} -> {String.to_charlist(path), body} end)

    {:ok, {_filename, zip_binary}} = :zip.create(~c"import.zip", entries, [:memory])
    zip_binary
  end
end
