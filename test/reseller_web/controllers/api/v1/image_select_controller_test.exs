defmodule ResellerWeb.API.V1.ImageSelectControllerTest do
  use ResellerWeb.ConnCase, async: true

  import Ecto.Query

  alias Reseller.Catalog
  alias Reseller.Media.ProductImage
  alias Reseller.Repo

  setup %{conn: conn} do
    user = user_fixture(%{"email" => "seller@example.com"})
    {raw_token, _api_token} = api_token_fixture(user, %{"device_name" => "iPhone"})

    authed_conn = put_req_header(conn, "authorization", "Bearer #{raw_token}")

    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Test sneakers"},
        [
          %{"filename" => "img1.jpg", "content_type" => "image/jpeg", "byte_size" => 10_000},
          %{"filename" => "img2.jpg", "content_type" => "image/jpeg", "byte_size" => 10_000}
        ],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [img1, img2] = product.images

    {:ok, %{product: product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => img1.id, "checksum" => "aaa", "width" => 1000, "height" => 1000},
        %{"id" => img2.id, "checksum" => "bbb", "width" => 1000, "height" => 1000}
      ])

    Repo.update_all(
      from(pi in ProductImage, where: pi.product_id == ^product.id and pi.kind == "original"),
      set: [processing_status: "ready"]
    )

    images = Enum.filter(product.images, &(&1.kind == "original"))

    %{conn: authed_conn, user: user, product: product, images: images}
  end

  describe "PATCH /api/v1/products/:id/images/:image_id/storefront" do
    test "sets storefront_visible", %{conn: conn, product: product, images: [img1, _img2]} do
      conn =
        patch(conn, "/api/v1/products/#{product.id}/images/#{img1.id}/storefront", %{
          "storefront_visible" => true
        })

      assert %{"data" => %{"product" => %{"id" => _}}} = json_response(conn, 200)
      assert Repo.get(ProductImage, img1.id).storefront_visible == true
    end

    test "sets storefront_position", %{conn: conn, product: product, images: [img1, _img2]} do
      conn =
        patch(conn, "/api/v1/products/#{product.id}/images/#{img1.id}/storefront", %{
          "storefront_position" => 3
        })

      assert %{"data" => %{"product" => %{"id" => _}}} = json_response(conn, 200)
      assert Repo.get(ProductImage, img1.id).storefront_position == 3
    end

    test "returns 404 for another user's product", %{
      conn: conn,
      images: [img1, _img2]
    } do
      other_user = user_fixture(%{"email" => "other@example.com"})

      {:ok, %{product: other_product}} =
        Catalog.create_product_for_user(
          other_user,
          %{"title" => "Other"},
          [%{"filename" => "a.jpg", "content_type" => "image/jpeg", "byte_size" => 1_000}],
          storage: Reseller.Support.Fakes.MediaStorage
        )

      conn =
        patch(conn, "/api/v1/products/#{other_product.id}/images/#{img1.id}/storefront", %{
          "storefront_visible" => true
        })

      assert json_response(conn, 404)
    end

    test "requires bearer token", %{conn: conn, product: product, images: [img1, _]} do
      conn =
        conn
        |> delete_req_header("authorization")
        |> patch("/api/v1/products/#{product.id}/images/#{img1.id}/storefront", %{
          "storefront_visible" => true
        })

      assert json_response(conn, 401)
    end
  end

  describe "PUT /api/v1/products/:id/images/storefront_order" do
    test "sets storefront_position in supplied order", %{
      conn: conn,
      product: product,
      images: [img1, img2]
    } do
      conn =
        put(conn, "/api/v1/products/#{product.id}/images/storefront_order", %{
          "image_ids" => [img2.id, img1.id]
        })

      assert %{"data" => %{"product" => %{"id" => _}}} = json_response(conn, 200)
      assert Repo.get(ProductImage, img2.id).storefront_position == 1
      assert Repo.get(ProductImage, img1.id).storefront_position == 2
    end

    test "returns 400 when image_ids is not a list", %{conn: conn, product: product} do
      conn =
        put(conn, "/api/v1/products/#{product.id}/images/storefront_order", %{
          "image_ids" => "not_a_list"
        })

      assert json_response(conn, 400)
    end

    test "returns 404 for another user's product", %{conn: conn, images: [img1, img2]} do
      other_user = user_fixture(%{"email" => "other2@example.com"})

      {:ok, %{product: other_product}} =
        Catalog.create_product_for_user(
          other_user,
          %{"title" => "Other"},
          [%{"filename" => "a.jpg", "content_type" => "image/jpeg", "byte_size" => 1_000}],
          storage: Reseller.Support.Fakes.MediaStorage
        )

      conn =
        put(conn, "/api/v1/products/#{other_product.id}/images/storefront_order", %{
          "image_ids" => [img1.id, img2.id]
        })

      assert json_response(conn, 404)
    end

    test "requires bearer token", %{conn: conn, product: product, images: [img1, img2]} do
      conn =
        conn
        |> delete_req_header("authorization")
        |> put("/api/v1/products/#{product.id}/images/storefront_order", %{
          "image_ids" => [img1.id, img2.id]
        })

      assert json_response(conn, 401)
    end
  end
end
