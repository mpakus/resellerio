defmodule ResellerWeb.Admin.ApiTokenLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Reseller.Accounts.ApiToken,
      repo: Reseller.Repo,
      create_changeset: &Reseller.Accounts.ApiToken.create_changeset/3,
      update_changeset: &Reseller.Accounts.ApiToken.update_changeset/3
    ]

  alias Backpex.Fields
  alias Reseller.Accounts

  @impl Backpex.LiveResource
  def singular_name, do: "API Token"

  @impl Backpex.LiveResource
  def plural_name, do: "API Tokens"

  @impl Backpex.LiveResource
  def fields do
    [
      user: %{
        module: Fields.BelongsTo,
        label: "User",
        display_field: :email,
        live_resource: ResellerWeb.Admin.UserLive
      },
      context: %{
        module: Fields.Text,
        label: "Context",
        searchable: true
      },
      device_name: %{
        module: Fields.Text,
        label: "Device Name",
        searchable: true
      },
      expires_at: %{
        module: Fields.DateTime,
        label: "Expires At"
      },
      last_used_at: %{
        module: Fields.DateTime,
        label: "Last Used At"
      },
      inserted_at: %{
        module: Fields.DateTime,
        label: "Issued At"
      },
      token_hash: %{
        module: Fields.Text,
        label: "Token Hash",
        only: [:show],
        render: &render_token_hash/1
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(assigns, action, _item) do
    Accounts.admin?(assigns.current_user) and action in [:index, :show, :delete]
  end

  @impl Backpex.LiveResource
  def layout(_assigns), do: {ResellerWeb.Layouts, :admin}

  def render_token_hash(assigns) do
    value =
      case assigns.value do
        token_hash when is_binary(token_hash) -> Base.encode16(token_hash, case: :lower)
        _ -> nil
      end

    assigns = Phoenix.Component.assign(assigns, :encoded_value, value)

    ~H"""
    <code class="break-all text-xs leading-6">{@encoded_value || "—"}</code>
    """
  end
end
