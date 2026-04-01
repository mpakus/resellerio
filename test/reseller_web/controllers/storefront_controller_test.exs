defmodule ResellerWeb.StorefrontControllerTest do
  use ResellerWeb.ConnCase, async: true

  alias Phoenix.Flash
  alias Reseller.Catalog
  alias Reseller.Marketplaces
  alias Reseller.Media.ProductImage
  alias Reseller.Repo

  test "GET /store/:slug renders the public catalog and filters search", %{conn: conn} do
    user = user_fixture(%{"email" => "public-store@example.com"})

    storefront =
      storefront_fixture(user, %{
        "slug" => "public-store",
        "title" => "Public Store",
        "enabled" => true
      })

    storefront_page_fixture(user, %{
      "title" => "Shipping",
      "slug" => "shipping",
      "body" => "Ships twice a week.",
      "published" => true
    })

    tote =
      public_product_fixture(user, %{
        "title" => "Canvas Market Tote",
        "notes" => "Farmer market favorite"
      })

    _coat =
      public_product_fixture(user, %{"title" => "Vintage Coat", "notes" => "Wool outerwear"})

    _hidden = product_fixture(user, %{"title" => "Hidden Draft", "status" => "draft"})

    response =
      conn
      |> get(~p"/store/#{storefront.slug}")
      |> html_response(200)

    assert response =~ ~s(id="storefront-shell")
    assert response =~ "Public Store"
    assert response =~ tote.title
    assert response =~ "Shipping"
    refute response =~ "Hidden Draft"

    filtered_response =
      conn
      |> get(~p"/store/#{storefront.slug}?q=farmer")
      |> html_response(200)

    assert filtered_response =~ tote.title
    refute filtered_response =~ "Vintage Coat"
    assert filtered_response =~ ~s(value="farmer")
  end

  test "GET /store/:slug/products/:product_ref renders the public product page", %{conn: conn} do
    user = user_fixture(%{"email" => "product-store@example.com"})

    storefront =
      storefront_fixture(user, %{
        "slug" => "product-store",
        "title" => "Product Store",
        "enabled" => true
      })

    product =
      public_product_with_marketplace_fixture(user, %{
        "title" => "Leather Weekender",
        "price" => "148.00",
        "notes" => "Heavyweight leather duffel with brass hardware."
      })

    response =
      conn
      |> get(storefront_product_path(storefront, product))
      |> html_response(200)

    assert response =~ ~s(id="storefront-product-detail")
    assert response =~ "Leather Weekender"
    assert response =~ "$148.00"
    assert response =~ "View on eBay"
    assert response =~ "https://www.ebay.com/itm/123456"
    assert response =~ storefront_product_path(storefront, product)
  end

  test "GET /store/:slug/pages/:page_slug renders a published custom page", %{conn: conn} do
    user = user_fixture(%{"email" => "page-store@example.com"})

    storefront =
      storefront_fixture(user, %{
        "slug" => "page-store",
        "title" => "Page Store",
        "enabled" => true
      })

    page =
      storefront_page_fixture(user, %{
        "title" => "Shipping",
        "slug" => "shipping",
        "menu_label" => "Shipping",
        "body" => "Ships every Tuesday.\n\nReturns accepted within 14 days.",
        "published" => true
      })

    response =
      conn
      |> get(storefront_page_path(storefront, page))
      |> html_response(200)

    assert response =~ ~s(id="storefront-page-detail")
    assert response =~ "Ships every Tuesday."
    assert response =~ "Returns accepted within 14 days."
  end

  test "GET /store routes return 404 for disabled storefronts and unpublished content", %{
    conn: conn
  } do
    user = user_fixture(%{"email" => "hidden-store@example.com"})

    storefront =
      storefront_fixture(user, %{
        "slug" => "hidden-store",
        "title" => "Hidden Store",
        "enabled" => true
      })

    product = product_fixture(user, %{"title" => "Hidden Weekender", "status" => "ready"})
    add_finalized_original_image(product)

    page =
      storefront_page_fixture(user, %{
        "title" => "Returns",
        "slug" => "returns",
        "body" => "Return details.",
        "published" => false
      })

    disabled_storefront =
      storefront_fixture(user_fixture(%{"email" => "disabled-store@example.com"}), %{
        "slug" => "disabled-store",
        "enabled" => false
      })

    disabled_store_response =
      conn
      |> get(~p"/store/#{disabled_storefront.slug}")
      |> html_response(404)

    assert disabled_store_response =~ "Not Found"

    product_not_found =
      conn
      |> get("/store/#{storefront.slug}/products/#{product.id}-hidden-weekender")
      |> html_response(404)

    assert product_not_found =~ ~s(id="storefront-not-found")
    assert product_not_found =~ "That product is not available right now."

    page_not_found =
      conn
      |> get(storefront_page_path(storefront, page))
      |> html_response(404)

    assert page_not_found =~ ~s(id="storefront-not-found")
    assert page_not_found =~ "That page is not available right now."
  end

  test "POST /store/:slug/products/:product_ref/inquiries persists and redirects with flash", %{
    conn: conn
  } do
    user = user_fixture(%{"email" => "inquiry-store@example.com"})

    storefront =
      storefront_fixture(user, %{
        "slug" => "inquiry-store",
        "title" => "Inquiry Store",
        "enabled" => true
      })

    product = public_product_fixture(user, %{"title" => "Leather Belt"})
    product_ref = "#{product.id}-leather-belt"

    conn =
      post(conn, ~p"/store/inquiry-store/products/#{product_ref}/inquiries", %{
        "inquiry" => %{
          "full_name" => "Jane Smith",
          "contact" => "jane@example.com",
          "message" => "Is this available in size M?",
          "website" => ""
        }
      })

    assert redirected_to(conn) == "/store/inquiry-store/products/#{product_ref}"
    assert Flash.get(conn.assigns.flash, :info) =~ "request has been sent"

    assert_received {:storefront_notifier_called, "inquiry-store@example.com", storefront_id,
                     _inquiry_id}

    assert storefront_id == storefront.id
  end

  test "POST /store/:slug/products/:product_ref/inquiries rejects honeypot submissions silently",
       %{conn: conn} do
    user = user_fixture(%{"email" => "honeypot-store@example.com"})

    _storefront =
      storefront_fixture(user, %{
        "slug" => "honeypot-store",
        "title" => "Honeypot Store",
        "enabled" => true
      })

    product = public_product_fixture(user, %{"title" => "Decoy Item"})
    product_ref = "#{product.id}-decoy-item"

    conn =
      post(conn, ~p"/store/honeypot-store/products/#{product_ref}/inquiries", %{
        "inquiry" => %{
          "full_name" => "Bot",
          "contact" => "bot@spam.com",
          "message" => "Spam message",
          "website" => "http://spam.example.com"
        }
      })

    assert redirected_to(conn) == "/store/honeypot-store/products/#{product_ref}"
    assert Flash.get(conn.assigns.flash, :info) =~ "Thank you"
    refute_received {:storefront_notifier_called, _, _, _}
  end

  test "POST /store/:slug/products/:product_ref/inquiries rejects invalid submissions", %{
    conn: conn
  } do
    user = user_fixture(%{"email" => "invalid-inquiry-store@example.com"})

    _storefront =
      storefront_fixture(user, %{
        "slug" => "invalid-inquiry-store",
        "title" => "Store",
        "enabled" => true
      })

    product = public_product_fixture(user, %{"title" => "Test Item"})
    product_ref = "#{product.id}-test-item"

    conn =
      post(conn, ~p"/store/invalid-inquiry-store/products/#{product_ref}/inquiries", %{
        "inquiry" => %{
          "full_name" => "",
          "contact" => "",
          "message" => "",
          "website" => ""
        }
      })

    assert redirected_to(conn) == "/store/invalid-inquiry-store/products/#{product_ref}"
    assert Flash.get(conn.assigns.flash, :error) =~ "Could not submit"
  end

  test "GET /store/:slug/products/:product_ref renders request form when no marketplace links", %{
    conn: conn
  } do
    user = user_fixture(%{"email" => "no-links-store@example.com"})

    _storefront =
      storefront_fixture(user, %{
        "slug" => "no-links-store",
        "title" => "No Links Store",
        "enabled" => true
      })

    product = public_product_fixture(user, %{"title" => "Plain Tote"})

    response =
      conn
      |> get("/store/no-links-store/products/#{product.id}-plain-tote")
      |> html_response(200)

    assert response =~ ~s(id="storefront-product-request")
    assert response =~ "Send Request"
    assert response =~ "Full Name"
    assert response =~ "Phone / Email"
    refute response =~ "Buy from an active listing"
  end

  defp public_product_fixture(user, attrs) do
    product =
      product_fixture(
        user,
        Enum.into(attrs, %{"title" => "Storefront Product", "status" => "ready"})
      )

    add_finalized_original_image(product)

    {:ok, published_product} =
      Catalog.update_product_for_user(user, product.id, %{"storefront_enabled" => true})

    published_product
  end

  defp public_product_with_marketplace_fixture(user, attrs) do
    product = public_product_fixture(user, attrs)

    {:ok, _listing} =
      Marketplaces.upsert_marketplace_listing(product, "ebay", %{
        "generated_title" => product.title,
        "generated_description" => product.notes || "Marketplace listing",
        "generated_tags" => ["vintage", "resale"]
      })

    {:ok, refreshed_product} =
      Catalog.update_product_review_for_user(user, product.id, %{}, %{
        "ebay" => "https://www.ebay.com/itm/123456"
      })

    refreshed_product
  end

  defp add_finalized_original_image(product) do
    %ProductImage{}
    |> ProductImage.create_changeset(%{
      "kind" => "original",
      "position" => 1,
      "storage_key" => "products/#{product.id}/#{System.unique_integer([:positive])}.jpg",
      "content_type" => "image/jpeg",
      "processing_status" => "ready",
      "original_filename" => "photo.jpg",
      "byte_size" => 2048,
      "width" => 1200,
      "height" => 1600
    })
    |> Ecto.Changeset.put_assoc(:product, product)
    |> Repo.insert!()
  end

  defp storefront_product_path(storefront, product) do
    "/store/#{storefront.slug}/products/#{product.id}-#{Reseller.Slugs.slugify(product.title || "", max_length: 80)}"
  end

  defp storefront_page_path(storefront, page) do
    "/store/#{storefront.slug}/pages/#{page.slug}"
  end
end
