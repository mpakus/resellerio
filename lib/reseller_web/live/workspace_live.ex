defmodule ResellerWeb.WorkspaceLive do
  use ResellerWeb, :live_view

  alias Reseller.Catalog
  alias Reseller.Exports
  alias Reseller.Imports

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Workspace",
       current_scope: nil,
       section_key: :dashboard,
       workspace_nav: [],
       stats: [],
       products: [],
       listing_rows: [],
       exports: [],
       imports: []
     )}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    section_key = socket.assigns.live_action || :dashboard
    current_user = socket.assigns.current_user
    products = Catalog.list_products_for_user(current_user)
    exports = Exports.list_exports_for_user(current_user)
    imports = Imports.list_imports_for_user(current_user)

    {:noreply,
     socket
     |> assign(
       section_key: section_key,
       page_title: page_title(section_key),
       workspace_nav: workspace_nav(section_key),
       products: products,
       listing_rows: listing_rows(products),
       exports: exports,
       imports: imports,
       stats: dashboard_stats(products, exports, imports),
       current_url: uri
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app_shell flash={@flash} current_user={@current_user} workspace_nav={@workspace_nav}>
      <section class="grid gap-8">
        <div class="grid gap-4 lg:grid-cols-[1.1fr_0.9fr] lg:items-end">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
              {section_eyebrow(@section_key)}
            </p>
            <h1
              id="workspace-heading"
              class="reseller-display mt-4 text-5xl font-semibold tracking-[-0.04em] text-balance"
            >
              {section_heading(@section_key)}
            </h1>
            <p class="mt-5 max-w-2xl text-base leading-7 text-base-content/70">
              {section_description(@section_key)}
            </p>
          </div>

          <div class="rounded-[2rem] border border-base-300 bg-base-100 p-6 shadow-[0_24px_70px_rgba(20,20,20,0.08)]">
            <p class="text-xs uppercase tracking-[0.3em] text-base-content/50">Current user</p>
            <p id="workspace-user-email" class="mt-4 text-2xl font-semibold tracking-[-0.03em]">
              {@current_user.email}
            </p>
            <p class="mt-2 text-sm text-base-content/65">
              Protected browser session is active.
            </p>
          </div>
        </div>

        <%= case @section_key do %>
          <% :dashboard -> %>
            <section id="workspace-dashboard" class="grid gap-4 xl:grid-cols-4">
              <article
                :for={stat <- @stats}
                class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6"
              >
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">{stat.label}</p>
                <p class="mt-4 text-3xl font-semibold tracking-[-0.03em]">{stat.value}</p>
                <p class="mt-3 text-sm leading-6 text-base-content/68">{stat.description}</p>
              </article>
            </section>

            <section class="grid gap-4 xl:grid-cols-[1.1fr_0.9fr]">
              <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
                <div class="flex items-center justify-between gap-4">
                  <div>
                    <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">
                      Recent products
                    </p>
                    <p class="mt-2 text-2xl font-semibold tracking-[-0.03em]">
                      Inventory at a glance
                    </p>
                  </div>
                  <.link patch={~p"/app/products"} class="btn btn-outline btn-sm rounded-full">
                    Open products
                  </.link>
                </div>

                <div class="mt-5 space-y-3">
                  <div
                    :for={product <- Enum.take(@products, 3)}
                    class="rounded-2xl border border-base-300 bg-base-50 px-4 py-4"
                  >
                    <div class="flex items-center justify-between gap-4">
                      <div>
                        <p class="text-sm font-semibold">{product.title || "Untitled product"}</p>
                        <p class="mt-1 text-xs uppercase tracking-[0.22em] text-base-content/50">
                          {product.brand || "No brand"} · {product.category || "No category"}
                        </p>
                      </div>
                      <span class="badge badge-outline">{product.status}</span>
                    </div>
                  </div>
                  <p :if={@products == []} class="text-sm text-base-content/60">
                    No products yet. Seed data or create a product to see inventory here.
                  </p>
                </div>
              </article>

              <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Operations</p>
                <p class="mt-2 text-2xl font-semibold tracking-[-0.03em]">What is ready now</p>
                <ul class="mt-5 space-y-3 text-sm leading-6 text-base-content/70">
                  <li>Products can be edited, archived, restored, or marked sold via the API.</li>
                  <li>Exports and imports are available through the API and summarized here.</li>
                  <li>
                    Marketplace listings and AI drafts are visible in the workspace product data.
                  </li>
                </ul>
              </article>
            </section>
          <% :products -> %>
            <section id="workspace-products" class="grid gap-4">
              <div class="overflow-hidden rounded-[1.75rem] border border-base-300 bg-base-100">
                <table class="table table-zebra">
                  <thead>
                    <tr>
                      <th>Product</th>
                      <th>Status</th>
                      <th>Price</th>
                      <th>Updated</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={product <- @products}>
                      <td>
                        <div class="font-semibold">{product.title || "Untitled product"}</div>
                        <div class="text-xs uppercase tracking-[0.2em] text-base-content/50">
                          {product.brand || "No brand"} · {product.category || "No category"}
                        </div>
                      </td>
                      <td><span class="badge badge-outline">{product.status}</span></td>
                      <td>{(product.price && Decimal.to_string(product.price, :normal)) || "—"}</td>
                      <td>{Calendar.strftime(product.updated_at, "%Y-%m-%d %H:%M")}</td>
                    </tr>
                    <tr :if={@products == []}>
                      <td colspan="4" class="text-sm text-base-content/60">No products found.</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </section>
          <% :listings -> %>
            <section id="workspace-listings" class="grid gap-4 md:grid-cols-2">
              <article
                :for={listing <- @listing_rows}
                class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6"
              >
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">
                  {listing.marketplace}
                </p>
                <p class="mt-3 text-xl font-semibold tracking-[-0.03em]">{listing.title}</p>
                <p class="mt-2 text-sm text-base-content/60">{listing.product_title}</p>
                <p class="mt-4 text-sm leading-6 text-base-content/70 line-clamp-3">
                  {listing.description}
                </p>
              </article>
              <p :if={@listing_rows == []} class="text-sm text-base-content/60">
                No marketplace listings yet.
              </p>
            </section>
          <% :exports -> %>
            <section id="workspace-exports" class="grid gap-4 xl:grid-cols-2">
              <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Exports</p>
                <div class="mt-5 space-y-3">
                  <div
                    :for={export <- @exports}
                    class="rounded-2xl border border-base-300 bg-base-50 px-4 py-4"
                  >
                    <div class="flex items-center justify-between gap-4">
                      <div>
                        <p class="text-sm font-semibold">Export #{export.id}</p>
                        <p class="mt-1 text-xs uppercase tracking-[0.2em] text-base-content/50">
                          {export.status}
                        </p>
                      </div>
                      <span class="badge badge-outline">{export.status}</span>
                    </div>
                  </div>
                  <p :if={@exports == []} class="text-sm text-base-content/60">No exports yet.</p>
                </div>
              </article>

              <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Imports</p>
                <div class="mt-5 space-y-3">
                  <div
                    :for={import_row <- @imports}
                    class="rounded-2xl border border-base-300 bg-base-50 px-4 py-4"
                  >
                    <div class="flex items-center justify-between gap-4">
                      <div>
                        <p class="text-sm font-semibold">{import_row.source_filename}</p>
                        <p class="mt-1 text-xs uppercase tracking-[0.2em] text-base-content/50">
                          {import_row.status}
                        </p>
                      </div>
                      <span class="badge badge-outline">{import_row.status}</span>
                    </div>
                  </div>
                  <p :if={@imports == []} class="text-sm text-base-content/60">No imports yet.</p>
                </div>
              </article>
            </section>
          <% :settings -> %>
            <section id="workspace-settings" class="grid gap-4 lg:grid-cols-[1fr_1fr]">
              <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Account</p>
                <p class="mt-3 text-2xl font-semibold tracking-[-0.03em]">{@current_user.email}</p>
                <p class="mt-3 text-sm leading-6 text-base-content/70">
                  Browser account settings and passkey setup will live here next.
                </p>
              </article>

              <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Workspace</p>
                <ul class="mt-4 space-y-3 text-sm leading-6 text-base-content/70">
                  <li>Theme switcher is already available in the header.</li>
                  <li>Admin users can jump into Backpex from the sidebar footer.</li>
                  <li>Future settings will include defaults for image backgrounds and passkeys.</li>
                </ul>
              </article>
            </section>
        <% end %>
      </section>
    </Layouts.app_shell>
    """
  end

  defp workspace_nav(active_section) do
    [
      %{label: "Dashboard", path: "/app", active: active_section == :dashboard},
      %{label: "Products", path: "/app/products", active: active_section == :products},
      %{label: "Listings", path: "/app/listings", active: active_section == :listings},
      %{label: "Exports", path: "/app/exports", active: active_section == :exports},
      %{label: "Settings", path: "/app/settings", active: active_section == :settings}
    ]
  end

  defp page_title(:dashboard), do: "Workspace"
  defp page_title(:products), do: "Products"
  defp page_title(:listings), do: "Listings"
  defp page_title(:exports), do: "Exports"
  defp page_title(:settings), do: "Settings"
  defp page_title(_section), do: "Workspace"

  defp section_eyebrow(:dashboard), do: "Dashboard"
  defp section_eyebrow(:products), do: "Inventory"
  defp section_eyebrow(:listings), do: "Listings"
  defp section_eyebrow(:exports), do: "Transfers"
  defp section_eyebrow(:settings), do: "Settings"
  defp section_eyebrow(_section), do: "Workspace"

  defp section_heading(:dashboard), do: "Your reseller workspace is now operational."
  defp section_heading(:products), do: "Browse and review your catalog."
  defp section_heading(:listings), do: "See marketplace-ready copy in one place."
  defp section_heading(:exports), do: "Track archive exports and imports."
  defp section_heading(:settings), do: "Manage your workspace defaults."
  defp section_heading(_section), do: "Your reseller workspace is ready."

  defp section_description(:dashboard) do
    "The dashboard now gives you a real landing screen with product, export, and import summaries instead of a static placeholder."
  end

  defp section_description(:products) do
    "This products screen surfaces current inventory records so the workspace menu lands on a real destination."
  end

  defp section_description(:listings) do
    "Marketplace listings generated by the AI pipeline are grouped here so you can review marketplace-specific output quickly."
  end

  defp section_description(:exports) do
    "Exports and imports now have a shared operational view so archive activity is visible from the web shell."
  end

  defp section_description(:settings) do
    "Settings is now a real workspace stop and will grow into account, passkey, and default-behavior controls."
  end

  defp section_description(_section) do
    "Protected browser session is active and the reseller menu now routes between real workspace sections."
  end

  defp dashboard_stats(products, exports, imports) do
    [
      %{
        label: "Products",
        value: length(products),
        description: "Total catalog records in this account."
      },
      %{
        label: "Ready",
        value: Enum.count(products, &(&1.status == "ready")),
        description: "Products currently ready for listing or sale."
      },
      %{
        label: "Exports",
        value: length(exports),
        description: "Archive exports created for this account."
      },
      %{
        label: "Imports",
        value: length(imports),
        description: "Archive imports processed for this account."
      }
    ]
  end

  defp listing_rows(products) do
    products
    |> Enum.flat_map(fn product ->
      Enum.map(product.marketplace_listings || [], fn listing ->
        %{
          marketplace: String.upcase(listing.marketplace),
          title: listing.generated_title || "Untitled listing",
          product_title: product.title || "Untitled product",
          description: listing.generated_description || "No generated description yet."
        }
      end)
    end)
  end
end
