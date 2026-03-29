defmodule ResellerWeb.Admin.UserLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Reseller.Accounts.User,
      repo: Reseller.Repo,
      create_changeset: &Reseller.Accounts.User.create_changeset/3,
      update_changeset: &Reseller.Accounts.User.update_changeset/3
    ]

  alias Backpex.Fields
  alias Reseller.Accounts

  @impl Backpex.LiveResource
  def singular_name, do: "User"

  @impl Backpex.LiveResource
  def plural_name, do: "Users"

  @impl Backpex.LiveResource
  def fields do
    [
      email: %{
        module: Fields.Text,
        label: "Email",
        searchable: true
      },
      is_admin: %{
        module: Fields.Boolean,
        label: "Admin"
      },
      confirmed_at: %{
        module: Fields.DateTime,
        label: "Confirmed At"
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
    Accounts.admin?(assigns.current_user) and action in [:index, :show, :edit, :delete]
  end

  @impl Backpex.LiveResource
  def layout(_assigns), do: {ResellerWeb.Layouts, :admin}
end
