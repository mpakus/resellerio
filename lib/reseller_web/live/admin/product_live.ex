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
  alias Reseller.Metrics

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

  @impl Backpex.LiveResource
  def render_resource_slot(assigns, :show, :after_main) do
    product_id = assigns.item.id
    usage = Metrics.usage_for_product(product_id)
    events = Metrics.list_events(product_id: product_id, limit: 20)

    assigns = assign(assigns, usage: usage, events: events)

    ~H"""
    <div class="mt-6 rounded-lg border border-base-300 bg-base-100">
      <div class="px-6 py-4 border-b border-base-300">
        <h2 class="text-base font-semibold">API Usage for this Product</h2>
      </div>
      <div class="p-6">
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-6">
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">Total Calls</div>
            <div class="stat-value text-lg">{@usage.total_calls}</div>
          </div>
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">Est. Cost</div>
            <div class="stat-value text-lg">${format_decimal(@usage.total_cost_usd, 4)}</div>
          </div>
        </div>

        <%= if @usage.by_operation != [] do %>
          <h3 class="text-sm font-semibold mb-2">By Operation</h3>
          <div class="overflow-x-auto mb-6">
            <table class="table table-sm w-full text-sm">
              <thead>
                <tr>
                  <th>Provider</th>
                  <th>Operation</th>
                  <th>Calls</th>
                  <th>Tokens</th>
                  <th>Est. Cost</th>
                </tr>
              </thead>
              <tbody>
                <%= for row <- @usage.by_operation do %>
                  <tr>
                    <td>{row.provider}</td>
                    <td>{row.operation}</td>
                    <td>{row.calls}</td>
                    <td>{row.total_tokens}</td>
                    <td>${format_decimal(row.total_cost_usd, 6)}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>

        <%= if @events != [] do %>
          <h3 class="text-sm font-semibold mb-2">Recent Events</h3>
          <div class="overflow-x-auto">
            <table class="table table-sm w-full text-sm">
              <thead>
                <tr>
                  <th>When</th>
                  <th>Provider</th>
                  <th>Operation</th>
                  <th>Status</th>
                  <th>Tokens</th>
                  <th>Cost</th>
                  <th>ms</th>
                </tr>
              </thead>
              <tbody>
                <%= for event <- @events do %>
                  <tr>
                    <td class="whitespace-nowrap">
                      {Calendar.strftime(event.inserted_at, "%m-%d %H:%M")}
                    </td>
                    <td>{event.provider}</td>
                    <td>{event.operation}</td>
                    <td class={if event.status == "error", do: "text-error", else: "text-success"}>
                      {event.status}
                    </td>
                    <td>{event.total_tokens}</td>
                    <td>${format_decimal(event.cost_usd, 6)}</td>
                    <td>{event.duration_ms}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_decimal(nil, _scale), do: "0.000000"
  defp format_decimal(%Decimal{} = d, scale), do: Decimal.to_string(Decimal.round(d, scale))

  defp format_decimal(n, scale) when is_number(n),
    do: :erlang.float_to_binary(n / 1, decimals: scale)

  defp format_decimal(_, _), do: "0.000000"
end
