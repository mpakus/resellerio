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
  alias Reseller.Metrics

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
      plan: %{
        module: Fields.Text,
        label: "Plan",
        only: [:index, :show, :edit]
      },
      plan_status: %{
        module: Fields.Text,
        label: "Plan Status",
        only: [:index, :show, :edit]
      },
      plan_expires_at: %{
        module: Fields.DateTime,
        label: "Plan Expires At",
        only: [:show, :edit]
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
  def filters do
    [
      plan_status: %{
        module: ResellerWeb.Admin.Filters.PlanStatusFilter,
        label: "Plan Status"
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(assigns, action, _item) do
    Accounts.admin?(assigns.current_user) and action in [:index, :show, :edit, :delete]
  end

  @impl Backpex.LiveResource
  def layout(_assigns), do: {ResellerWeb.Layouts, :admin}

  @impl Backpex.LiveResource
  def render_resource_slot(assigns, :show, :after_main) do
    user_id = assigns.item.id
    user = assigns.item

    since_30d = DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)

    usage_30d = Metrics.usage_for_user(user_id, since: since_30d)
    usage_all = Metrics.usage_for_user(user_id, since: ~U[2020-01-01 00:00:00Z])

    days_left = Reseller.Billing.days_until_expiry(user)

    assigns =
      assign(assigns,
        usage_30d: usage_30d,
        usage_all: usage_all,
        days_left: days_left
      )

    ~H"""
    <div class="mt-6 rounded-lg border border-base-300 bg-base-100">
      <div class="px-6 py-4 border-b border-base-300">
        <h2 class="text-base font-semibold">Subscription</h2>
      </div>
      <div class="p-6 grid gap-4 sm:grid-cols-3">
        <div>
          <p class="text-xs text-base-content/50 uppercase tracking-wide">Plan</p>
          <p class="mt-1 font-semibold">{@item.plan || "free"}</p>
        </div>
        <div>
          <p class="text-xs text-base-content/50 uppercase tracking-wide">Status</p>
          <p class="mt-1 font-semibold">{@item.plan_status || "free"}</p>
        </div>
        <div>
          <p class="text-xs text-base-content/50 uppercase tracking-wide">Period</p>
          <p class="mt-1 font-semibold">{@item.plan_period || "—"}</p>
        </div>
        <div>
          <p class="text-xs text-base-content/50 uppercase tracking-wide">Expires At</p>
          <p class="mt-1 font-semibold">
            {if @item.plan_expires_at,
              do: Calendar.strftime(@item.plan_expires_at, "%b %d, %Y"),
              else: "—"}
          </p>
        </div>
        <div>
          <p class="text-xs text-base-content/50 uppercase tracking-wide">Days Left</p>
          <p class="mt-1 font-semibold">{@days_left || "—"}</p>
        </div>
        <div>
          <p class="text-xs text-base-content/50 uppercase tracking-wide">LS Subscription ID</p>
          <p class="mt-1 font-mono text-sm">{@item.ls_subscription_id || "—"}</p>
        </div>
        <%= if map_size(@item.addon_credits || %{}) > 0 do %>
          <div class="sm:col-span-3">
            <p class="text-xs text-base-content/50 uppercase tracking-wide">Add-on Credits</p>
            <div class="mt-1 flex flex-wrap gap-2">
              <span
                :for={{key, qty} <- @item.addon_credits}
                class="badge badge-ghost border border-base-300 px-3 py-1.5 text-xs"
              >
                {qty} × {String.replace(key, "_", " ")}
              </span>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <div class="mt-6 rounded-lg border border-base-300 bg-base-100">
      <div class="px-6 py-4 border-b border-base-300">
        <h2 class="text-base font-semibold">API Usage Metrics</h2>
      </div>
      <div class="p-6">
        <p class="text-sm text-base-content/60 mb-4">Last 30 days</p>
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-6">
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">Gemini Calls</div>
            <div class="stat-value text-lg">{@usage_30d.gemini_calls}</div>
          </div>
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">Gemini Tokens</div>
            <div class="stat-value text-lg">{@usage_30d.gemini_tokens}</div>
          </div>
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">SerpApi Calls</div>
            <div class="stat-value text-lg">{@usage_30d.serp_api_calls}</div>
          </div>
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">Photoroom Calls</div>
            <div class="stat-value text-lg">{@usage_30d.photoroom_calls}</div>
          </div>
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">Est. Cost (30d)</div>
            <div class="stat-value text-lg">${format_decimal(@usage_30d.total_cost_usd, 4)}</div>
          </div>
          <div class="stat bg-base-200 rounded-lg p-4">
            <div class="stat-title text-xs">Est. Cost (all time)</div>
            <div class="stat-value text-lg">${format_decimal(@usage_all.total_cost_usd, 4)}</div>
          </div>
        </div>
        <.link
          navigate={"/admin/api-usage-events?filters[user_id]=#{@item.id}"}
          class="btn btn-sm btn-outline"
        >
          View All Events
        </.link>
      </div>
    </div>
    """
  end

  defp format_decimal(nil, _scale), do: "0.0000"
  defp format_decimal(%Decimal{} = d, scale), do: Decimal.to_string(Decimal.round(d, scale))

  defp format_decimal(n, scale) when is_number(n),
    do: :erlang.float_to_binary(n / 1, decimals: scale)

  defp format_decimal(_, _), do: "0.0000"
end
