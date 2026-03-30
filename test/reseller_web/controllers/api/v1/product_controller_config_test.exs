defmodule ResellerWeb.API.V1.ProductControllerConfigTest do
  use ResellerWeb.ConnCase, async: false

  setup %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    {raw_token, _api_token} = api_token_fixture(user, %{"device_name" => "iPhone"})

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{raw_token}")

    %{conn: conn}
  end

  test "POST /api/v1/products returns env var names for storage misconfiguration", %{conn: conn} do
    with_tigris_storage_missing!(:access_key_id, fn ->
      conn =
        post(conn, "/api/v1/products", %{
          "product" => %{"title" => "Upload test"},
          "uploads" => [
            %{
              "filename" => "shoe-1.jpg",
              "content_type" => "image/jpeg",
              "byte_size" => 345_678
            }
          ]
        })

      assert json_response(conn, 502) == %{
               "error" => %{
                 "code" => "storage_unavailable",
                 "detail" => "Storage upload signing is not configured: TIGRIS_ACCESS_KEY_ID",
                 "status" => 502
               }
             }
    end)
  end

  defp with_tigris_storage_missing!(missing_key, fun) do
    previous_media = Application.get_env(:reseller, Reseller.Media)
    previous_tigris = Application.get_env(:reseller, Reseller.Media.Storage.Tigris)

    Application.put_env(
      :reseller,
      Reseller.Media,
      Keyword.put(previous_media, :storage, Reseller.Media.Storage.Tigris)
    )

    Application.put_env(
      :reseller,
      Reseller.Media.Storage.Tigris,
      access_key_id: if(missing_key == :access_key_id, do: nil, else: "tigris-access"),
      secret_access_key: if(missing_key == :secret_access_key, do: nil, else: "tigris-secret"),
      base_url:
        if(missing_key == :base_url,
          do: nil,
          else: "https://bucket.example.tigris.dev"
        )
    )

    try do
      fun.()
    after
      Application.put_env(:reseller, Reseller.Media, previous_media)
      Application.put_env(:reseller, Reseller.Media.Storage.Tigris, previous_tigris)
    end
  end
end
