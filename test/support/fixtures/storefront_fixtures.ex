defmodule Reseller.StorefrontFixtures do
  alias Reseller.Storefronts

  def storefront_fixture(user, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        "slug" => "seller-#{System.unique_integer([:positive])}",
        "title" => "Seller storefront",
        "theme_id" => Reseller.Storefronts.ThemePresets.default_id(),
        "enabled" => false
      })

    case Storefronts.upsert_storefront_for_user(user, attrs) do
      {:ok, storefront} ->
        storefront

      {:error, changeset} ->
        raise "could not create storefront fixture: #{inspect(changeset.errors)}"
    end
  end

  def storefront_page_fixture(user, attrs \\ %{}) do
    case Storefronts.get_storefront_for_user(user) do
      nil -> storefront_fixture(user)
      storefront -> storefront
    end

    attrs =
      Enum.into(attrs, %{
        "title" => "About",
        "body" => "About this seller."
      })

    case Storefronts.create_storefront_page_for_user(user, attrs) do
      {:ok, page} ->
        page

      {:error, reason} ->
        raise "could not create storefront page fixture: #{inspect(reason)}"
    end
  end

  def inquiry_fixture(user, attrs \\ %{}) do
    storefront =
      case Storefronts.get_storefront_for_user(user) do
        nil -> storefront_fixture(user)
        s -> s
      end

    attrs =
      Enum.into(attrs, %{
        "full_name" => "Test Buyer",
        "contact" => "buyer@example.com",
        "message" => "Is this still available?",
        "source_path" => "/store/#{storefront.slug}/products/1-test-product"
      })

    case Storefronts.create_storefront_inquiry(storefront, attrs) do
      {:ok, inquiry} ->
        inquiry

      {:error, reason} ->
        raise "could not create inquiry fixture: #{inspect(reason)}"
    end
  end
end
