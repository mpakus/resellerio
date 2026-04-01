defmodule ResellerWeb.StorefrontHTML do
  use ResellerWeb, :html
  import ResellerWeb.StorefrontComponents

  embed_templates "storefront_html/*"

  def share_url(storefront, product) do
    ResellerWeb.Endpoint.url() <> storefront_product_path(storefront, product)
  end

  def marketplace_link_copy(listing) do
    "View on #{storefront_marketplace_label(listing)}"
  end

  def missing_heading("product"), do: "That product is not available right now."
  def missing_heading("page"), do: "That page is not available right now."
  def missing_heading(_kind), do: "This storefront content is not available right now."

  def missing_description("product", missing_target) when is_binary(missing_target) do
    "The product reference \"#{missing_target}\" does not map to a live storefront item."
  end

  def missing_description("page", missing_target) when is_binary(missing_target) do
    "The page \"#{missing_target}\" is missing or unpublished."
  end

  def missing_description(_kind, _missing_target) do
    "Try returning to the storefront catalog to browse what is currently live."
  end
end
