defmodule Reseller.Marketplaces.MarketplaceListingTest do
  use Reseller.DataCase, async: true

  alias Reseller.Marketplaces.MarketplaceListing

  test "create_changeset/2 validates external listing URLs" do
    changeset =
      MarketplaceListing.create_changeset(%MarketplaceListing{}, %{
        "marketplace" => "ebay",
        "status" => "generated",
        "generated_title" => "Vintage jacket",
        "generated_description" => "Single-breasted wool jacket.",
        "external_url" => "ftp://example.com/listing/123"
      })

    assert %{external_url: ["must be a valid http or https URL"]} = errors_on(changeset)
  end

  test "update_changeset/2 stamps external_url_added_at when a URL is stored" do
    changeset =
      MarketplaceListing.update_changeset(%MarketplaceListing{}, %{
        "marketplace" => "ebay",
        "status" => "generated",
        "generated_title" => "Vintage jacket",
        "generated_description" => "Single-breasted wool jacket.",
        "external_url" => "https://example.com/listing/123"
      })

    assert changeset.valid?
    assert get_change(changeset, :external_url) == "https://example.com/listing/123"
    assert %DateTime{} = get_change(changeset, :external_url_added_at)
  end

  test "update_changeset/2 clears external_url_added_at when the URL is removed" do
    listing = %MarketplaceListing{
      marketplace: "ebay",
      status: "generated",
      generated_title: "Vintage jacket",
      generated_description: "Single-breasted wool jacket.",
      external_url: "https://example.com/listing/123",
      external_url_added_at: ~U[2026-03-31 12:00:00Z]
    }

    changeset =
      MarketplaceListing.update_changeset(listing, %{
        "marketplace" => "ebay",
        "status" => "generated",
        "generated_title" => "Vintage jacket",
        "generated_description" => "Single-breasted wool jacket.",
        "external_url" => "   "
      })

    assert changeset.valid?
    assert get_change(changeset, :external_url) == nil
    assert get_change(changeset, :external_url_added_at) == nil
  end
end
