defmodule ResellerWeb.Admin.StorefrontLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Reseller.Storefronts.Storefront,
      repo: Reseller.Repo,
      create_changeset: &Reseller.Storefronts.Storefront.create_changeset/3,
      update_changeset: &Reseller.Storefronts.Storefront.update_changeset/3
    ]

  alias Backpex.Fields
  alias Reseller.Accounts

  @impl Backpex.LiveResource
  def singular_name, do: "Storefront"

  @impl Backpex.LiveResource
  def plural_name, do: "Storefronts"

  @impl Backpex.LiveResource
  def fields do
    [
      slug: %{
        module: Fields.Text,
        label: "Slug",
        searchable: true
      },
      title: %{
        module: Fields.Text,
        label: "Title",
        searchable: true
      },
      tagline: %{
        module: Fields.Text,
        label: "Tagline"
      },
      theme_id: %{
        module: Fields.Text,
        label: "Theme"
      },
      enabled: %{
        module: Fields.Boolean,
        label: "Enabled"
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
