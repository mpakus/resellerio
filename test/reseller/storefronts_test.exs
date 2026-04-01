defmodule Reseller.StorefrontsTest do
  use Reseller.DataCase, async: true

  alias Reseller.Catalog
  alias Reseller.Media.ProductImage
  alias Reseller.Repo
  alias Reseller.Storefronts
  alias Reseller.Storefronts.Storefront
  alias Reseller.Storefronts.ThemePresets

  test "upsert_storefront_for_user/2 creates a normalized storefront with defaults" do
    user = user_fixture()

    assert {:ok, storefront} =
             Storefronts.upsert_storefront_for_user(user, %{
               "slug" => "  Fresh Threads!!!  ",
               "title" => "  Fresh Threads  ",
               "tagline" => "  Vintage and repaired  "
             })

    assert storefront.user_id == user.id
    assert storefront.slug == "fresh-threads"
    assert storefront.title == "Fresh Threads"
    assert storefront.tagline == "Vintage and repaired"
    assert storefront.theme_id == ThemePresets.default_id()
    assert storefront.enabled == false
    assert storefront.assets == []
    assert storefront.pages == []
  end

  test "upsert_storefront_for_user/2 updates the seller's existing storefront" do
    user = user_fixture()
    storefront = storefront_fixture(user, %{"slug" => "initial-store", "title" => "Initial"})

    assert {:ok, updated_storefront} =
             Storefronts.upsert_storefront_for_user(user, %{
               "slug" => "renamed-store",
               "title" => "Renamed",
               "theme_id" => "linen-ink",
               "enabled" => true
             })

    assert updated_storefront.id == storefront.id
    assert updated_storefront.slug == "renamed-store"
    assert updated_storefront.title == "Renamed"
    assert updated_storefront.theme_id == "linen-ink"
    assert updated_storefront.enabled == true

    assert Repo.aggregate(Storefront, :count) == 1
  end

  test "upsert_storefront_for_user/2 rejects invalid and duplicate slugs" do
    user = user_fixture()
    other_user = user_fixture()
    _existing = storefront_fixture(other_user, %{"slug" => "shared-store"})

    assert {:error, invalid_changeset} =
             Storefronts.upsert_storefront_for_user(user, %{
               "slug" => "!!!",
               "title" => "Broken",
               "theme_id" => ThemePresets.default_id()
             })

    assert %{slug: ["can't be blank"]} = errors_on(invalid_changeset)

    assert {:error, duplicate_changeset} =
             Storefronts.upsert_storefront_for_user(user, %{
               "slug" => "shared store",
               "title" => "Duplicate",
               "theme_id" => ThemePresets.default_id()
             })

    assert %{slug: ["has already been taken"]} = errors_on(duplicate_changeset)
  end

  test "upsert_storefront_for_user/2 rejects unsupported theme ids" do
    user = user_fixture()

    assert {:error, changeset} =
             Storefronts.upsert_storefront_for_user(user, %{
               "slug" => "fresh-threads",
               "title" => "Fresh Threads",
               "theme_id" => "missing-theme"
             })

    assert %{theme_id: ["is invalid"]} = errors_on(changeset)
  end

  test "get_or_build_storefront_for_user/1 returns an unsaved storefront when none exists" do
    user = user_fixture()

    storefront = Storefronts.get_or_build_storefront_for_user(user)

    assert storefront.id == nil
    assert storefront.user_id == user.id
    assert storefront.theme_id == ThemePresets.default_id()
    assert storefront.enabled == false
  end

  test "get_storefront_by_slug/1 returns only enabled storefronts" do
    user = user_fixture()
    other_user = user_fixture()

    enabled_storefront =
      storefront_fixture(user, %{"slug" => "fresh-threads", "enabled" => true})

    _disabled_storefront =
      storefront_fixture(other_user, %{"slug" => "hidden-store", "enabled" => false})

    assert %Storefront{id: id} = Storefronts.get_storefront_by_slug(" Fresh Threads ")
    assert id == enabled_storefront.id
    assert Storefronts.get_storefront_by_slug("hidden-store") == nil
  end

  test "create_storefront_page_for_user/2 auto-slugifies and orders pages" do
    user = user_fixture()
    _storefront = storefront_fixture(user)

    assert {:ok, about_page} =
             Storefronts.create_storefront_page_for_user(user, %{
               "title" => " About Us ",
               "body" => "About this seller."
             })

    assert {:ok, shipping_page} =
             Storefronts.create_storefront_page_for_user(user, %{
               "title" => "Shipping Details",
               "menu_label" => "Shipping",
               "body" => "Ships within two days."
             })

    assert about_page.slug == "about-us"
    assert about_page.menu_label == "About Us"
    assert about_page.position == 1
    assert shipping_page.slug == "shipping-details"
    assert shipping_page.menu_label == "Shipping"
    assert shipping_page.position == 2

    assert Enum.map(Storefronts.list_storefront_pages_for_user(user), &{&1.slug, &1.position}) ==
             [
               {"about-us", 1},
               {"shipping-details", 2}
             ]
  end

  test "storefront page access is ownership scoped" do
    user = user_fixture()
    other_user = user_fixture()
    page = storefront_page_fixture(user, %{"title" => "About"})
    other_page = storefront_page_fixture(other_user, %{"title" => "Returns"})

    assert Storefronts.get_storefront_page_for_user(user, page.id).id == page.id
    assert Storefronts.get_storefront_page_for_user(user, other_page.id) == nil

    assert {:error, :not_found} =
             Storefronts.update_storefront_page_for_user(user, other_page.id, %{
               "title" => "Nope"
             })

    assert {:error, :not_found} = Storefronts.delete_storefront_page_for_user(user, other_page.id)
  end

  test "create_storefront_page_for_user/2 requires a storefront and enforces unique slugs per storefront" do
    user = user_fixture()

    assert {:error, :storefront_not_found} =
             Storefronts.create_storefront_page_for_user(user, %{
               "title" => "About",
               "body" => "About body."
             })

    _storefront = storefront_fixture(user)
    _page = storefront_page_fixture(user, %{"title" => "About"})

    assert {:error, changeset} =
             Storefronts.create_storefront_page_for_user(user, %{
               "title" => "Another title",
               "slug" => "about",
               "body" => "Different body."
             })

    assert %{slug: ["has already been taken"]} = errors_on(changeset)
  end

  test "upsert_storefront_asset_for_user/3 keeps a single asset per kind" do
    user = user_fixture()
    _storefront = storefront_fixture(user)

    assert {:ok, logo} =
             Storefronts.upsert_storefront_asset_for_user(user, "logo", %{
               "storage_key" => "users/1/storefront/logo-1.png",
               "content_type" => "image/png",
               "original_filename" => "logo.png",
               "width" => 512,
               "height" => 512,
               "byte_size" => 16_384
             })

    assert {:ok, updated_logo} =
             Storefronts.upsert_storefront_asset_for_user(user, "logo", %{
               "storage_key" => "users/1/storefront/logo-2.png",
               "content_type" => "image/png",
               "original_filename" => "logo-2.png",
               "width" => 1024,
               "height" => 1024,
               "byte_size" => 32_768
             })

    assert updated_logo.id == logo.id
    assert updated_logo.storage_key == "users/1/storefront/logo-2.png"
    assert Storefronts.get_storefront_asset_for_user(user, "logo").id == updated_logo.id
  end

  test "create_storefront_inquiry/2 validates and persists inquiry data" do
    user = user_fixture()
    storefront = storefront_fixture(user)
    product = product_fixture(user, %{"title" => "Canvas Tote"})

    assert {:ok, inquiry} =
             Storefronts.create_storefront_inquiry(storefront, %{
               "product_id" => product.id,
               "full_name" => "  Alex Doe  ",
               "contact" => "  alex@example.com  ",
               "message" => "  Is this still available?  ",
               "source_path" => "/store/#{storefront.slug}/products/#{product.id}-canvas-tote"
             })

    assert inquiry.product_id == product.id
    assert inquiry.full_name == "Alex Doe"
    assert inquiry.contact == "alex@example.com"
    assert inquiry.message == "Is this still available?"

    assert_received {:storefront_notifier_called, _email, _storefront_id, _inquiry_id}

    assert {:error, changeset} =
             Storefronts.create_storefront_inquiry(storefront, %{
               "full_name" => " ",
               "contact" => " ",
               "message" => " ",
               "source_path" => " "
             })

    assert %{
             full_name: ["can't be blank"],
             contact: ["can't be blank"],
             message: ["can't be blank"],
             source_path: ["can't be blank"]
           } = errors_on(changeset)
  end

  test "create_storefront_inquiry/2 rate-limits by IP" do
    user = user_fixture()
    storefront = storefront_fixture(user)

    base_attrs = %{
      "full_name" => "Spammer",
      "contact" => "spam@example.com",
      "message" => "Available?",
      "source_path" => "/store/test",
      "requester_ip" => "1.2.3.4"
    }

    ip_limit = Application.fetch_env!(:reseller, Reseller.Storefronts)[:inquiry_ip_limit]

    for _ <- 1..ip_limit do
      assert {:ok, _} = Storefronts.create_storefront_inquiry(storefront, base_attrs)
    end

    assert {:error, :rate_limited} =
             Storefronts.create_storefront_inquiry(storefront, base_attrs)
  end

  test "list_public_products/2 only returns storefront-enabled ready products and filters search" do
    user = user_fixture()
    storefront = storefront_fixture(user, %{"slug" => "public-seller", "enabled" => true})

    public_product =
      product_fixture(user, %{
        "title" => "Canvas Market Tote",
        "status" => "ready",
        "notes" => "Farmer market favorite"
      })

    add_finalized_original_image(public_product)

    assert {:ok, _product} =
             Catalog.update_product_for_user(user, public_product.id, %{
               "storefront_enabled" => true
             })

    hidden_product =
      product_fixture(user, %{"title" => "Private Jacket", "status" => "ready"})

    add_finalized_original_image(hidden_product)

    other_user = user_fixture()

    _other_storefront =
      storefront_fixture(other_user, %{"slug" => "other-store", "enabled" => true})

    other_product =
      product_fixture(other_user, %{"title" => "Other Seller Tote", "status" => "ready"})

    add_finalized_original_image(other_product)

    assert {:ok, _product} =
             Catalog.update_product_for_user(other_user, other_product.id, %{
               "storefront_enabled" => true
             })

    assert Enum.map(Storefronts.list_public_products(storefront), & &1.title) == [
             "Canvas Market Tote"
           ]

    assert Enum.map(Storefronts.list_public_products(storefront, query: "farmer"), & &1.title) ==
             ["Canvas Market Tote"]

    assert Storefronts.list_public_products(storefront, query: "jacket") == []
  end

  test "get_public_product/2 and get_public_page/2 only expose published content" do
    user = user_fixture()
    storefront = storefront_fixture(user, %{"slug" => "seller-archive", "enabled" => true})

    public_product = product_fixture(user, %{"title" => "Leather Weekender", "status" => "ready"})
    add_finalized_original_image(public_product)

    assert {:ok, _product} =
             Catalog.update_product_for_user(user, public_product.id, %{
               "storefront_enabled" => true
             })

    _draft_product = product_fixture(user, %{"title" => "Hidden Draft", "status" => "draft"})

    published_page =
      storefront_page_fixture(user, %{
        "title" => "Shipping",
        "slug" => "shipping",
        "body" => "Ships twice a week.",
        "published" => true
      })

    unpublished_page =
      storefront_page_fixture(user, %{
        "title" => "Returns",
        "slug" => "returns",
        "body" => "Return details.",
        "published" => false
      })

    assert %Reseller.Catalog.Product{id: id} =
             Storefronts.get_public_product(storefront, "#{public_product.id}-wrong-slug")

    assert id == public_product.id
    assert Storefronts.get_public_product(storefront, "999999") == nil
    assert Storefronts.get_public_page(storefront, published_page.slug).id == published_page.id
    assert Storefronts.get_public_page(storefront, unpublished_page.slug) == nil
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

  test "list_inquiries_for_user/2 returns paginated inquiries scoped to the user" do
    user = user_fixture()
    other_user = user_fixture()
    _storefront = storefront_fixture(user, %{"slug" => "user-inquiries", "enabled" => true})

    _other_storefront =
      storefront_fixture(other_user, %{"slug" => "other-inquiries", "enabled" => true})

    inquiry_fixture(user, %{"full_name" => "Alice", "message" => "Is the jacket available?"})
    inquiry_fixture(user, %{"full_name" => "Bob", "message" => "What size is it?"})
    inquiry_fixture(other_user, %{"full_name" => "Stranger", "message" => "Different store."})

    result = Storefronts.list_inquiries_for_user(user)

    assert result.total_count == 2
    assert length(result.entries) == 2
    assert Enum.all?(result.entries, fn i -> i.storefront.user_id == user.id end)

    names = Enum.map(result.entries, & &1.full_name)
    assert "Alice" in names
    assert "Bob" in names
    refute "Stranger" in names
  end

  test "list_inquiries_for_user/2 searches across name, contact, and message" do
    user = user_fixture()
    _storefront = storefront_fixture(user, %{"slug" => "search-inquiries", "enabled" => true})

    inquiry_fixture(user, %{
      "full_name" => "Alice Jacket",
      "contact" => "alice@example.com",
      "message" => "About the coat"
    })

    inquiry_fixture(user, %{
      "full_name" => "Bob",
      "contact" => "bob@example.com",
      "message" => "Asking about jacket sizing"
    })

    inquiry_fixture(user, %{
      "full_name" => "Carol",
      "contact" => "carol@jacket.com",
      "message" => "Just browsing"
    })

    inquiry_fixture(user, %{
      "full_name" => "Dave",
      "contact" => "dave@example.com",
      "message" => "Hello"
    })

    name_result = Storefronts.list_inquiries_for_user(user, query: "alice jacket")
    assert name_result.total_count == 1
    assert hd(name_result.entries).full_name == "Alice Jacket"

    msg_result = Storefronts.list_inquiries_for_user(user, query: "jacket sizing")
    assert msg_result.total_count == 1
    assert hd(msg_result.entries).full_name == "Bob"

    contact_result = Storefronts.list_inquiries_for_user(user, query: "jacket.com")
    assert contact_result.total_count == 1
    assert hd(contact_result.entries).full_name == "Carol"

    no_result = Storefronts.list_inquiries_for_user(user, query: "nomatch_xyz")
    assert no_result.total_count == 0
    assert no_result.entries == []
  end

  test "list_inquiries_for_user/2 paginates correctly" do
    user = user_fixture()
    _storefront = storefront_fixture(user, %{"slug" => "paginated-inquiries", "enabled" => true})

    for n <- 1..5 do
      inquiry_fixture(user, %{"full_name" => "Buyer #{n}", "message" => "Message #{n}"})
    end

    page1 = Storefronts.list_inquiries_for_user(user, page: 1, page_size: 2)
    assert page1.total_count == 5
    assert page1.total_pages == 3
    assert length(page1.entries) == 2
    assert page1.page == 1

    page2 = Storefronts.list_inquiries_for_user(user, page: 2, page_size: 2)
    assert length(page2.entries) == 2
    assert page2.page == 2

    page3 = Storefronts.list_inquiries_for_user(user, page: 3, page_size: 2)
    assert length(page3.entries) == 1
    assert page3.page == 3

    ids_page1 = Enum.map(page1.entries, & &1.id)
    ids_page2 = Enum.map(page2.entries, & &1.id)
    assert Enum.empty?(ids_page1 -- (ids_page1 -- ids_page2))
  end

  test "delete_inquiry_for_user/2 removes the inquiry when owned by the user" do
    user = user_fixture()
    _storefront = storefront_fixture(user, %{"slug" => "delete-inquiries", "enabled" => true})
    inquiry = inquiry_fixture(user)

    assert {:ok, deleted} = Storefronts.delete_inquiry_for_user(user, inquiry.id)
    assert deleted.id == inquiry.id
    assert Repo.get(Reseller.Storefronts.StorefrontInquiry, inquiry.id) == nil
  end

  test "delete_inquiry_for_user/2 returns not_found for another user's inquiry" do
    user = user_fixture()
    other_user = user_fixture()

    _storefront =
      storefront_fixture(other_user, %{"slug" => "other-delete-inquiries", "enabled" => true})

    other_inquiry = inquiry_fixture(other_user)

    assert {:error, :not_found} = Storefronts.delete_inquiry_for_user(user, other_inquiry.id)
  end

  test "delete_inquiry_for_user/2 returns not_found for a missing id" do
    user = user_fixture()
    assert {:error, :not_found} = Storefronts.delete_inquiry_for_user(user, 0)
    assert {:error, :not_found} = Storefronts.delete_inquiry_for_user(user, "not-an-id")
  end
end
