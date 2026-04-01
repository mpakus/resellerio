defmodule ResellerWeb.Admin.ProductLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Reseller.Catalog.Product,
      repo: Reseller.Repo,
      create_changeset: &Reseller.Catalog.Product.create_changeset/3,
      update_changeset: &Reseller.Catalog.Product.update_changeset/3
    ]

  alias Backpex.Fields
  alias Reseller.Accounts

  @impl Backpex.LiveResource
  def singular_name, do: "Product"

  @impl Backpex.LiveResource
  def plural_name, do: "Products"

  @impl Backpex.LiveResource
  def fields do
    [
      title: %{
        module: Fields.Text,
        label: "Title",
        searchable: true
      },
      status: %{
        module: Fields.Text,
        label: "Status"
      },
      brand: %{
        module: Fields.Text,
        label: "Brand",
        searchable: true
      },
      category: %{
        module: Fields.Text,
        label: "Category"
      },
      price: %{
        module: Fields.Number,
        label: "Price"
      },
      sku: %{
        module: Fields.Text,
        label: "SKU",
        searchable: true
      },
      source: %{
        module: Fields.Text,
        label: "Source"
      },
      storefront_enabled: %{
        module: Fields.Boolean,
        label: "Storefront",
        only: [:index, :show]
      },
      inserted_at: %{
        module: Fields.DateTime,
        label: "Created At",
        only: [:index, :show]
      },
      updated_at: %{
        module: Fields.DateTime,
        label: "Updated At",
        only: [:show]
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(assigns, action, _item) do
    Accounts.admin?(assigns.current_user) and action in [:index, :show, :edit, :update]
  end

  @impl Backpex.LiveResource
  def layout(_assigns), do: {ResellerWeb.Layouts, :admin}
end
