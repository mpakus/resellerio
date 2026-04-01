defmodule ResellerWeb.Admin.UsageDashboardLive do
  use ResellerWeb, :live_view

  alias Reseller.Metrics
  alias Reseller.Repo

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load_data(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Backpex.HTML.Layout.app_shell live_resource={nil} fluid={false}>
      <:topbar>
        <div class="flex min-w-0 flex-1 items-center justify-between gap-4">
          <div class="min-w-0">
            <p class="text-xs uppercase tracking-[0.3em] text-base-content/50">Admin interface</p>
            <p class="truncate text-sm font-semibold">{@current_user.email}</p>
          </div>
          <div class="flex items-center gap-2">
            <.link navigate={~p"/app"} class="btn btn-ghost btn-sm rounded-full">Workspace</.link>
            <.link href={~p"/sign-out"} method="delete" class="btn btn-primary btn-sm rounded-full">
              Sign out
            </.link>
          </div>
        </div>
      </:topbar>
      <:sidebar>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/admin/users/">
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-users" class="size-4" /> Users
          </span>
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/admin/api-tokens/">
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-key" class="size-4" /> API Tokens
          </span>
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/admin/products/">
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-squares-2x2" class="size-4" /> Products
          </span>
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/admin/storefronts/">
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-building-storefront" class="size-4" /> Storefronts
          </span>
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item
          current_url={@current_url}
          navigate="/admin/api-usage-events/"
        >
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-chart-bar" class="size-4" /> API Events
          </span>
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/admin/usage-dashboard">
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-presentation-chart-line" class="size-4" /> Usage Dashboard
          </span>
        </Backpex.HTML.Layout.sidebar_item>
      </:sidebar>

      <div class="space-y-8 p-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold">Usage Dashboard</h1>
            <p class="text-sm text-base-content/60 mt-1">Platform-wide API usage and cost overview</p>
          </div>
          <.link navigate="/admin/api-usage-events/" class="btn btn-outline btn-sm">
            View Raw Events
          </.link>
        </div>

        <section>
          <h2 class="text-base font-semibold mb-3">Platform Totals — Last 30 Days</h2>
          <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
            <div class="stat bg-base-100 rounded-xl border border-base-300 p-4">
              <div class="stat-title text-xs">Total Calls</div>
              <div class="stat-value text-xl">{@totals.total_calls}</div>
            </div>
            <div class="stat bg-base-100 rounded-xl border border-base-300 p-4">
              <div class="stat-title text-xs">Gemini Calls</div>
              <div class="stat-value text-xl">{@totals.gemini_calls}</div>
            </div>
            <div class="stat bg-base-100 rounded-xl border border-base-300 p-4">
              <div class="stat-title text-xs">Gemini Tokens</div>
              <div class="stat-value text-xl">{format_number(@totals.gemini_tokens)}</div>
            </div>
            <div class="stat bg-base-100 rounded-xl border border-base-300 p-4">
              <div class="stat-title text-xs">SerpApi Calls</div>
              <div class="stat-value text-xl">{@totals.serp_api_calls}</div>
            </div>
            <div class="stat bg-base-100 rounded-xl border border-base-300 p-4">
              <div class="stat-title text-xs">Photoroom Calls</div>
              <div class="stat-value text-xl">{@totals.photoroom_calls}</div>
            </div>
            <div class="stat bg-base-100 rounded-xl border border-base-300 p-4">
              <div class="stat-title text-xs">Est. Cost</div>
              <div class="stat-value text-xl">${format_decimal(@totals.total_cost_usd, 2)}</div>
            </div>
          </div>
        </section>

        <section>
          <h2 class="text-base font-semibold mb-3">Daily Trend — Last 30 Days</h2>
          <div class="overflow-x-auto rounded-xl border border-base-300 bg-base-100">
            <table class="table table-sm w-full text-sm">
              <thead>
                <tr>
                  <th>Date</th>
                  <th class="text-right">Calls</th>
                  <th class="text-right">Tokens</th>
                  <th class="text-right">Est. Cost</th>
                </tr>
              </thead>
              <tbody>
                <%= if @daily_totals == [] do %>
                  <tr>
                    <td colspan="4" class="text-center text-base-content/50 py-6">No data yet</td>
                  </tr>
                <% end %>
                <%= for row <- @daily_totals do %>
                  <tr>
                    <td>{row.date}</td>
                    <td class="text-right">{row.calls}</td>
                    <td class="text-right">{format_number(row.total_tokens)}</td>
                    <td class="text-right">${format_decimal(row.total_cost_usd, 4)}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </section>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <section>
            <h2 class="text-base font-semibold mb-3">Top Users by Cost — Last 30 Days</h2>
            <div class="overflow-x-auto rounded-xl border border-base-300 bg-base-100">
              <table class="table table-sm w-full text-sm">
                <thead>
                  <tr>
                    <th>User</th>
                    <th class="text-right">Calls</th>
                    <th class="text-right">Tokens</th>
                    <th class="text-right">Est. Cost</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @top_users == [] do %>
                    <tr>
                      <td colspan="4" class="text-center text-base-content/50 py-6">No data yet</td>
                    </tr>
                  <% end %>
                  <%= for row <- @top_users do %>
                    <tr>
                      <td>
                        <.link
                          navigate={"/admin/users/#{row.user_id}"}
                          class="link link-hover text-xs"
                        >
                          {user_email(@users_by_id, row.user_id)}
                        </.link>
                      </td>
                      <td class="text-right">{row.calls}</td>
                      <td class="text-right">{format_number(row.total_tokens)}</td>
                      <td class="text-right">${format_decimal(row.total_cost_usd, 4)}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </section>

          <section>
            <h2 class="text-base font-semibold mb-3">Top Products by Cost — Last 30 Days</h2>
            <div class="overflow-x-auto rounded-xl border border-base-300 bg-base-100">
              <table class="table table-sm w-full text-sm">
                <thead>
                  <tr>
                    <th>Product</th>
                    <th class="text-right">Calls</th>
                    <th class="text-right">Tokens</th>
                    <th class="text-right">Est. Cost</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if @top_products == [] do %>
                    <tr>
                      <td colspan="4" class="text-center text-base-content/50 py-6">No data yet</td>
                    </tr>
                  <% end %>
                  <%= for row <- @top_products do %>
                    <tr>
                      <td>
                        <.link
                          navigate={"/admin/products/#{row.product_id}"}
                          class="link link-hover text-xs"
                        >
                          {product_title(@products_by_id, row.product_id)}
                        </.link>
                      </td>
                      <td class="text-right">{row.calls}</td>
                      <td class="text-right">{format_number(row.total_tokens)}</td>
                      <td class="text-right">${format_decimal(row.total_cost_usd, 4)}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </section>
        </div>

        <section>
          <h2 class="text-base font-semibold mb-3">Error Summary — Last 30 Days</h2>
          <div class="overflow-x-auto rounded-xl border border-base-300 bg-base-100">
            <table class="table table-sm w-full text-sm">
              <thead>
                <tr>
                  <th>Provider</th>
                  <th>Operation</th>
                  <th class="text-right">Errors</th>
                </tr>
              </thead>
              <tbody>
                <%= if @error_summary == [] do %>
                  <tr>
                    <td colspan="3" class="text-center text-base-content/50 py-6">No errors</td>
                  </tr>
                <% end %>
                <%= for row <- @error_summary do %>
                  <tr>
                    <td>{row.provider}</td>
                    <td>{row.operation}</td>
                    <td class="text-right text-error">{row.error_count}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </section>
      </div>

      <Backpex.HTML.Layout.flash_messages flash={@flash} />
    </Backpex.HTML.Layout.app_shell>
    """
  end

  defp load_data(socket) do
    since_30d = DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)

    totals = Metrics.platform_totals(since: since_30d)
    daily_totals = Metrics.platform_daily_totals(days: 30)
    top_users = Metrics.top_users_by_cost(days: 30, limit: 10)
    top_products = Metrics.top_products_by_cost(days: 30, limit: 10)
    error_summary = Metrics.error_summary(days: 30)

    user_ids = Enum.map(top_users, & &1.user_id) |> Enum.filter(& &1)
    product_ids = Enum.map(top_products, & &1.product_id) |> Enum.filter(& &1)

    users_by_id = load_users_by_id(user_ids)
    products_by_id = load_products_by_id(product_ids)

    assign(socket,
      totals: totals,
      daily_totals: daily_totals,
      top_users: top_users,
      top_products: top_products,
      error_summary: error_summary,
      users_by_id: users_by_id,
      products_by_id: products_by_id
    )
  end

  defp load_users_by_id([]), do: %{}

  defp load_users_by_id(ids) do
    import Ecto.Query

    Repo.all(from u in Reseller.Accounts.User, where: u.id in ^ids, select: {u.id, u.email})
    |> Map.new()
  end

  defp load_products_by_id([]), do: %{}

  defp load_products_by_id(ids) do
    import Ecto.Query

    Repo.all(from p in Reseller.Catalog.Product, where: p.id in ^ids, select: {p.id, p.title})
    |> Map.new()
  end

  defp user_email(users_by_id, user_id) do
    Map.get(users_by_id, user_id, "User ##{user_id}")
  end

  defp product_title(products_by_id, product_id) do
    case Map.get(products_by_id, product_id) do
      nil -> "Product ##{product_id}"
      "" -> "Product ##{product_id}"
      title -> String.slice(title, 0, 30)
    end
  end

  defp format_number(nil), do: "0"

  defp format_number(n) when is_integer(n) and n >= 1_000_000,
    do: "#{Float.round(n / 1_000_000, 1)}M"

  defp format_number(n) when is_integer(n) and n >= 1_000, do: "#{Float.round(n / 1_000, 1)}K"
  defp format_number(n) when is_integer(n), do: to_string(n)
  defp format_number(n), do: to_string(n)

  defp format_decimal(nil, _scale), do: "0.00"
  defp format_decimal(%Decimal{} = d, scale), do: Decimal.to_string(Decimal.round(d, scale))

  defp format_decimal(n, scale) when is_number(n),
    do: :erlang.float_to_binary(n / 1, decimals: scale)

  defp format_decimal(_, _), do: "0.00"
end
