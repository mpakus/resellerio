defmodule ResellerWeb.ProductsLive.Index do
  use ResellerWeb, :live_view

  alias Reseller.Catalog
  alias Reseller.Exports
  alias ResellerWeb.ProductsLive.Helpers
  alias ResellerWeb.WorkspaceNavigation

  @page_size 15
  @sortable_columns [
    %{label: "Product", value: "title"},
    %{label: "Status", value: "status"},
    %{label: "Price", value: "price"},
    %{label: "Updated", value: "updated_at"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Exports.subscribe(socket.assigns.current_user)
    end

    {:ok,
     assign(socket,
       page_title: ResellerWeb.PageTitle.build("Products", "Workspace / Inventory"),
       workspace_nav: WorkspaceNavigation.items(:products),
       product_filters: Helpers.product_filters(),
       sortable_product_columns: @sortable_columns,
       product_filter: "all",
       product_index_page: 1,
       product_index_page_size: @page_size,
       product_index_total_pages: 1,
       product_index_total_count: 0,
       product_index_sort: "updated_at",
       product_index_sort_dir: "desc",
       product_index_query: nil,
       product_index_updated_from: nil,
       product_index_updated_to: nil,
       export_request_form: to_form(%{"name" => "Products export"}, as: :export),
       show_export_modal?: false,
       latest_export_id: nil,
       active_export: nil,
       active_export_download_url: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case parse_integer(Map.get(params, "product_id")) do
      nil ->
        {:noreply, assign_index(socket, params)}

      product_id ->
        {:noreply, push_navigate(socket, to: ~p"/app/products/#{product_id}")}
    end
  end

  @impl true
  def handle_event("change_product_filters", %{"filters" => filters}, socket) do
    {:noreply,
     push_patch(
       socket,
       to:
         index_path(socket.assigns, %{
           "status" => Map.get(filters, "status", socket.assigns.product_filter),
           "query" => Map.get(filters, "query", socket.assigns.product_index_query),
           "updated_from" => Map.get(filters, "updated_from"),
           "updated_to" => Map.get(filters, "updated_to"),
           "sort" => socket.assigns.product_index_sort,
           "dir" => socket.assigns.product_index_sort_dir,
           "page" => "1"
         })
     )}
  end

  def handle_event("open_export_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_export_modal?: true,
       active_export: nil,
       active_export_download_url: nil,
       export_request_form: build_export_request_form(socket.assigns)
     )}
  end

  def handle_event("close_export_modal", _params, socket) do
    {:noreply, assign(socket, show_export_modal?: false)}
  end

  def handle_event("request_filtered_export", %{"export" => export_params}, socket) do
    case Exports.request_export_for_user(socket.assigns.current_user,
           name: Map.get(export_params, "name"),
           filters: current_export_filters(socket.assigns)
         ) do
      {:ok, export} ->
        {:noreply,
         assign(socket,
           latest_export_id: export.id,
           active_export: export,
           active_export_download_url: maybe_export_download_url(export),
           show_export_modal?: true
         )}

      {:error, :no_products} ->
        {:noreply, put_flash(socket, :error, "No matching products are available to export.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         assign(socket,
           show_export_modal?: true,
           export_request_form: to_form(%{changeset | action: :validate}, as: :export)
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not start export: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({:export_updated, export}, socket) do
    if export.id == socket.assigns.latest_export_id do
      {:noreply,
       assign(socket,
         active_export: export,
         active_export_download_url: maybe_export_download_url(export),
         show_export_modal?:
           socket.assigns.show_export_modal? or export.status in ["completed", "failed"]
       )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app_shell
      flash={@flash}
      current_user={@current_user}
      workspace_nav={@workspace_nav}
      nav_mode={:navigate}
    >
      <section class="grid gap-8">
        <div class="grid gap-4 lg:grid-cols-[1.1fr_0.9fr] lg:items-end">
          <.section_intro
            id="products-index-heading"
            eyebrow="Inventory"
            title="Browse inventory in a real products table."
            description="Use the products index to search in real time, paginate catalog results, sort key columns, and narrow the result set by updated date before jumping into the separate intake and review forms."
            title_class="reseller-display mt-4 text-5xl font-semibold tracking-[-0.04em] text-balance"
            class="gap-0"
          />

          <.surface tag="div" class="rounded-[2rem]">
            <p class="text-xs uppercase tracking-[0.3em] text-base-content/50">Current user</p>
            <p id="products-index-user-email" class="mt-4 text-2xl font-semibold tracking-[-0.03em]">
              {@current_user.email}
            </p>
            <p class="mt-2 text-sm text-base-content/65">
              Table on the left, dedicated intake and review flows on their own LiveViews.
            </p>
            <div class="mt-5 flex flex-wrap gap-2">
              <.link navigate={~p"/app/products/new"} class="btn btn-primary btn-sm rounded-full">
                + Add product
              </.link>
              <.link navigate={~p"/app/exports"} class="btn btn-outline btn-sm rounded-full">
                Exports & imports
              </.link>
            </div>
          </.surface>
        </div>

        <section id="workspace-products" class="grid gap-4">
          <.surface tag="article">
            <div class="flex flex-wrap items-center justify-between gap-4">
              <div>
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">
                  Inventory
                </p>
                <p class="mt-2 text-2xl font-semibold tracking-[-0.03em]">
                  Products index
                </p>
                <p class="mt-2 max-w-2xl text-sm leading-6 text-base-content/70">
                  This page is table-first. Search, filters, sorting, and pagination stay focused here while uploads and edits live on separate routes.
                </p>
              </div>
              <div class="flex flex-wrap gap-2">
                <button
                  id="open-export-modal-button"
                  type="button"
                  phx-click="open_export_modal"
                  disabled={@product_index_total_count == 0}
                  class={[
                    "btn btn-outline btn-sm rounded-full",
                    @product_index_total_count == 0 && "btn-disabled"
                  ]}
                >
                  Export filtered
                </button>
                <.link navigate={~p"/app/products/new"} class="btn btn-primary btn-sm rounded-full">
                  + Add product
                </.link>
              </div>
            </div>

            <div class="mt-5 flex flex-wrap gap-2" id="product-filters">
              <.link
                :for={{label, value} <- @product_filters}
                patch={index_path(assigns, %{"status" => value, "page" => "1"})}
                class={[
                  "rounded-full border px-4 py-2 text-sm transition",
                  @product_filter == value && "border-primary bg-primary text-primary-content",
                  @product_filter != value &&
                    "border-base-300 bg-base-200/60 text-base-content/70 hover:border-primary/35"
                ]}
              >
                {label}
              </.link>
            </div>

            <.form
              :let={filters_form}
              for={
                to_form(
                  %{
                    "status" => @product_filter,
                    "query" => @product_index_query,
                    "updated_from" => @product_index_updated_from,
                    "updated_to" => @product_index_updated_to
                  },
                  as: :filters
                )
              }
              id="product-date-range-form"
              phx-change="change_product_filters"
              class="mt-5 grid gap-3 xl:grid-cols-[minmax(0,1.4fr)_1fr_1fr_auto]"
            >
              <.input
                field={filters_form[:query]}
                type="search"
                label="Search products"
                placeholder="Title, brand, SKU, tags, notes..."
                phx-debounce="250"
              />
              <.input field={filters_form[:updated_from]} type="date" label="Updated from" />
              <.input field={filters_form[:updated_to]} type="date" label="Updated to" />
              <div class="flex items-end gap-2">
                <.link
                  :if={@product_index_query}
                  patch={index_path(assigns, %{"query" => nil, "page" => "1"})}
                  class="btn btn-ghost rounded-full"
                >
                  Clear search
                </.link>
                <.link
                  patch={
                    index_path(assigns, %{"updated_from" => nil, "updated_to" => nil, "page" => "1"})
                  }
                  class="btn btn-ghost rounded-full"
                >
                  Clear dates
                </.link>
              </div>
            </.form>

            <p class="mt-4 text-sm text-base-content/60">
              Export uses the current search and filters, then packages all {@product_index_total_count} matching products across every page into one ZIP archive.
            </p>
          </.surface>

          <.surface tag="article" padding="none" class="overflow-hidden">
            <div class="flex flex-wrap items-center justify-between gap-3 border-b border-base-300 px-6 py-4">
              <div>
                <p class="text-xs uppercase tracking-[0.22em] text-base-content/50">
                  {range_summary(
                    @product_index_page,
                    @product_index_page_size,
                    @product_index_total_count
                  )}
                </p>
                <p class="mt-1 text-sm text-base-content/70">
                  Sorted by {humanize_sort(@product_index_sort)} {String.upcase(
                    @product_index_sort_dir
                  )}
                </p>
                <p :if={@product_index_query} class="mt-1 text-sm text-base-content/60">
                  Searching for "{@product_index_query}"
                </p>
              </div>
              <div class="flex flex-wrap gap-2">
                <.link
                  :for={column <- @sortable_product_columns}
                  id={"product-sort-#{column.value}"}
                  patch={sort_path(assigns, column.value)}
                  class={[
                    "rounded-full border px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] transition",
                    @product_index_sort == column.value && "border-primary bg-primary/10 text-primary",
                    @product_index_sort != column.value &&
                      "border-base-300 bg-base-100 text-base-content/65 hover:border-primary/35"
                  ]}
                >
                  {column.label} {sort_indicator(
                    @product_index_sort,
                    @product_index_sort_dir,
                    column.value
                  )}
                </.link>
              </div>
            </div>

            <div class="overflow-x-auto">
              <table class="table table-zebra" id="workspace-products-table">
                <thead>
                  <tr>
                    <th>Product</th>
                    <th>Status</th>
                    <th>Readiness</th>
                    <th>Price</th>
                    <th>Updated</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody id="workspace-products-rows" phx-update="stream">
                  <tr :for={{row_id, product} <- @streams.product_rows} id={row_id}>
                    <td>
                      <div class="flex items-center gap-3">
                        <div class="size-14 overflow-hidden rounded-2xl border border-base-300 bg-base-200">
                          <img
                            :if={thumbnail = Helpers.thumbnail_image(product)}
                            src={Helpers.public_image_url(thumbnail)}
                            alt={thumbnail.original_filename || product.title || "Product image"}
                            class="size-full object-cover"
                          />
                        </div>
                        <div>
                          <div class="font-semibold">{product.title || "Untitled product"}</div>
                          <div class="text-xs uppercase tracking-[0.2em] text-base-content/50">
                            {product.brand || "No brand"} · {product.category || "No category"}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <.status_badge status={product.status} />
                    </td>
                    <td>
                      <div class="flex flex-wrap gap-2">
                        <span class="badge badge-outline">
                          {length(product.marketplace_listings)} markets
                        </span>
                        <span
                          :if={run = List.first(product.processing_runs)}
                          class="badge badge-outline"
                        >
                          {run.status}
                        </span>
                      </div>
                    </td>
                    <td>{Helpers.decimal_to_string(product.price) || "—"}</td>
                    <td>{Helpers.format_datetime(product.updated_at)}</td>
                    <td class="text-right">
                      <.link
                        navigate={~p"/app/products/#{product.id}"}
                        class="btn btn-ghost btn-xs rounded-full"
                      >
                        Review
                      </.link>
                    </td>
                  </tr>
                  <tr id="workspace-products-empty" class="hidden only:table-row">
                    <td colspan="6" class="py-10 text-center text-sm text-base-content/60">
                      No products matched the current search and filters.
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div class="flex flex-wrap items-center justify-between gap-3 border-t border-base-300 px-6 py-4">
              <p class="text-sm text-base-content/65">
                Page {@product_index_page} of {@product_index_total_pages}
              </p>
              <div class="flex gap-2">
                <%= if @product_index_page <= 1 do %>
                  <span class="btn btn-ghost btn-sm rounded-full btn-disabled">Previous</span>
                <% else %>
                  <.link
                    id="products-page-previous"
                    patch={page_path(assigns, @product_index_page - 1)}
                    class="btn btn-ghost btn-sm rounded-full"
                  >
                    Previous
                  </.link>
                <% end %>

                <%= if @product_index_page >= @product_index_total_pages do %>
                  <span class="btn btn-outline btn-sm rounded-full btn-disabled">Next</span>
                <% else %>
                  <.link
                    id="products-page-next"
                    patch={page_path(assigns, @product_index_page + 1)}
                    class="btn btn-outline btn-sm rounded-full"
                  >
                    Next
                  </.link>
                <% end %>
              </div>
            </div>
          </.surface>
        </section>

        <div
          :if={@show_export_modal?}
          id="products-export-modal"
          class="fixed inset-0 z-50 flex items-center justify-center px-4 py-8"
        >
          <button
            type="button"
            phx-click="close_export_modal"
            class="absolute inset-0 bg-neutral/55"
            aria-label="Close export modal"
          >
          </button>

          <.surface
            tag="section"
            class="relative z-10 w-full max-w-2xl border-base-300 bg-base-100 shadow-[0_30px_90px_rgba(20,20,20,0.28)]"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">
                  Archive export
                </p>
                <p class="mt-2 text-2xl font-semibold tracking-[-0.03em]">
                  {export_modal_title(@active_export)}
                </p>
                <p class="mt-2 text-sm leading-6 text-base-content/68">
                  {export_modal_description(@active_export, @product_index_total_count)}
                </p>
              </div>
              <button
                type="button"
                phx-click="close_export_modal"
                class="btn btn-ghost btn-sm rounded-full"
              >
                <.icon name="hero-x-mark" class="size-5" />
              </button>
            </div>

            <%= if @active_export do %>
              <div class="mt-6 grid gap-4">
                <.surface tag="div" variant="soft" padding="md">
                  <div class="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <p class="text-sm font-semibold">{@active_export.name}</p>
                      <p class="mt-1 text-sm text-base-content/60">
                        {export_product_count_label(@active_export.product_count)} · {Exports.filter_summary(
                          @active_export.filter_params || %{}
                        )}
                      </p>
                    </div>
                    <.status_badge status={@active_export.status} />
                  </div>
                </.surface>

                <%= cond do %>
                  <% @active_export.status in ["queued", "running"] -> %>
                    <p class="text-sm leading-6 text-base-content/68">
                      The archive is generating in the background. Leave this page if you want. We’ll keep the finished file on the Exports screen and send it by email when delivery succeeds.
                    </p>
                  <% @active_export.status == "completed" -> %>
                    <div class="flex flex-wrap gap-2">
                      <a
                        :if={@active_export_download_url}
                        id="download-export-link"
                        href={@active_export_download_url}
                        download={@active_export.file_name}
                        class="btn btn-primary rounded-full"
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        Download ZIP
                      </a>
                      <.link navigate={~p"/app/exports"} class="btn btn-outline rounded-full">
                        Open export history
                      </.link>
                    </div>
                  <% @active_export.status == "failed" -> %>
                    <p class="text-sm leading-6 text-error">
                      {@active_export.error_message ||
                        "Export failed. Check the export history and try again."}
                    </p>
                  <% true -> %>
                    <p class="text-sm leading-6 text-base-content/68">
                      Export status updated.
                    </p>
                <% end %>
              </div>
            <% else %>
              <.form
                for={@export_request_form}
                id="request-export-form"
                phx-submit="request_filtered_export"
                class="mt-6 grid gap-4"
              >
                <.input
                  field={@export_request_form[:name]}
                  type="text"
                  label="Export name"
                  placeholder="Products export"
                />

                <.surface tag="div" variant="soft" padding="md" class="grid gap-3">
                  <p class="text-sm font-semibold">
                    {export_product_count_label(@product_index_total_count)}
                  </p>
                  <p class="text-sm leading-6 text-base-content/68">
                    The ZIP will contain `Products.xls`, `manifest.json`, and one image folder per product under `images/&lt;product_id&gt;/...`.
                  </p>
                  <div class="flex flex-wrap gap-2">
                    <span
                      :for={detail <- current_export_filter_details(assigns)}
                      class="badge badge-outline rounded-full px-3 py-3 text-xs uppercase tracking-[0.16em]"
                    >
                      {detail.label}: {detail.value}
                    </span>
                  </div>
                </.surface>

                <div class="flex flex-wrap gap-2">
                  <button type="submit" class="btn btn-primary rounded-full">
                    Start background export
                  </button>
                  <button
                    type="button"
                    phx-click="close_export_modal"
                    class="btn btn-ghost rounded-full"
                  >
                    Cancel
                  </button>
                </div>
              </.form>
            <% end %>
          </.surface>
        </div>
      </section>
    </Layouts.app_shell>
    """
  end

  defp assign_index(socket, params) do
    product_page = product_page(socket.assigns.current_user, params)

    socket
    |> assign(
      product_filter: product_page.status,
      product_index_page: product_page.page,
      product_index_page_size: product_page.page_size,
      product_index_total_pages: product_page.total_pages,
      product_index_total_count: product_page.total_count,
      product_index_sort: Atom.to_string(product_page.sort),
      product_index_sort_dir: Atom.to_string(product_page.sort_dir),
      product_index_query: product_page.query,
      product_index_updated_from: date_input_value(product_page.updated_from),
      product_index_updated_to: date_input_value(product_page.updated_to)
    )
    |> stream(:product_rows, product_page.entries, reset: true)
  end

  defp product_page(current_user, params) do
    Catalog.paginate_products_for_user(current_user,
      page: Map.get(params, "page"),
      page_size: @page_size,
      status: normalize_product_filter(Map.get(params, "status")),
      query: normalize_product_search_query(Map.get(params, "query")),
      updated_from: parse_date(Map.get(params, "updated_from")),
      updated_to: parse_date(Map.get(params, "updated_to")),
      sort: normalize_product_sort(Map.get(params, "sort")),
      sort_dir: normalize_product_sort_dir(Map.get(params, "dir"))
    )
  end

  defp normalize_product_filter(filter)
       when filter in ~w(all draft uploading processing review ready sold archived),
       do: filter

  defp normalize_product_filter(_filter), do: "all"

  defp normalize_product_search_query(query) when is_binary(query) do
    case String.trim(query) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_product_search_query(_query), do: nil

  defp normalize_product_sort(sort)
       when sort in ["title", "status", "price", "updated_at", "inserted_at"],
       do: sort

  defp normalize_product_sort(_sort), do: "updated_at"

  defp normalize_product_sort_dir(sort_dir) when sort_dir in ["asc", "desc"], do: sort_dir
  defp normalize_product_sort_dir(_sort_dir), do: "desc"

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _other -> nil
    end
  end

  defp parse_date(_value), do: nil

  defp date_input_value(%Date{} = date), do: Date.to_iso8601(date)
  defp date_input_value(value) when is_binary(value), do: value
  defp date_input_value(_value), do: nil

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp parse_integer(_value), do: nil

  defp index_path(assigns, overrides) do
    build_path(
      "/app/products",
      %{
        "status" => assigns.product_filter,
        "query" => assigns.product_index_query,
        "updated_from" => assigns.product_index_updated_from,
        "updated_to" => assigns.product_index_updated_to,
        "sort" => assigns.product_index_sort,
        "dir" => assigns.product_index_sort_dir,
        "page" => assigns.product_index_page
      }
      |> Map.merge(overrides)
    )
  end

  defp sort_path(assigns, sort) do
    index_path(assigns, %{
      "sort" => sort,
      "dir" => next_sort_dir(assigns.product_index_sort, assigns.product_index_sort_dir, sort),
      "page" => "1"
    })
  end

  defp page_path(assigns, page) do
    page =
      page
      |> max(1)
      |> min(assigns.product_index_total_pages)

    index_path(assigns, %{"page" => page})
  end

  defp build_path(base_path, params) do
    query =
      params
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" or value == "all" end)
      |> Enum.into(%{})
      |> URI.encode_query()

    if query == "", do: base_path, else: base_path <> "?" <> query
  end

  defp next_sort_dir(current_sort, current_dir, current_sort) do
    if current_dir == "asc", do: "desc", else: "asc"
  end

  defp next_sort_dir(_current_sort, _current_dir, sort)
       when sort in ["price", "updated_at", "inserted_at"],
       do: "desc"

  defp next_sort_dir(_current_sort, _current_dir, _sort), do: "asc"

  defp range_summary(_page, _page_size, 0), do: "No products"

  defp range_summary(page, page_size, total_count) do
    first = (page - 1) * page_size + 1
    last = min(page * page_size, total_count)
    "Showing #{first}-#{last} of #{total_count} products"
  end

  defp humanize_sort("updated_at"), do: "updated time"
  defp humanize_sort("inserted_at"), do: "created time"
  defp humanize_sort("title"), do: "title"
  defp humanize_sort("status"), do: "status"
  defp humanize_sort("price"), do: "price"
  defp humanize_sort(sort), do: sort

  defp build_export_request_form(assigns) do
    to_form(%{"name" => default_export_name(assigns)}, as: :export)
  end

  defp default_export_name(assigns) do
    prefix =
      cond do
        is_binary(assigns.product_index_query) and assigns.product_index_query != "" ->
          "Search export"

        assigns.product_filter != "all" ->
          "#{String.capitalize(assigns.product_filter)} products"

        true ->
          "Products export"
      end

    "#{prefix} #{Date.utc_today() |> Date.to_iso8601()}"
  end

  defp current_export_filters(assigns) do
    Exports.normalize_filter_params(%{
      "status" => assigns.product_filter,
      "query" => assigns.product_index_query,
      "updated_from" => assigns.product_index_updated_from,
      "updated_to" => assigns.product_index_updated_to,
      "sort" => assigns.product_index_sort,
      "dir" => assigns.product_index_sort_dir
    })
  end

  defp current_export_filter_details(assigns) do
    assigns
    |> current_export_filters()
    |> Exports.filter_details()
    |> case do
      [] -> [%{label: "Filters", value: "All products"}]
      details -> details
    end
  end

  defp maybe_export_download_url(%{status: "completed"} = export) do
    case Exports.download_url(export) do
      {:ok, download_url} -> download_url
      {:error, _reason} -> nil
    end
  end

  defp maybe_export_download_url(_export), do: nil

  defp export_modal_title(nil), do: "Export the current table results"
  defp export_modal_title(%{status: "completed"}), do: "Export is ready"
  defp export_modal_title(%{status: "failed"}), do: "Export failed"
  defp export_modal_title(_export), do: "Export is running"

  defp export_modal_description(nil, total_count) do
    "Create a background ZIP for the #{export_product_count_label(total_count)} currently matching this table."
  end

  defp export_modal_description(%{status: "completed"}, _total_count) do
    "The archive is ready to download now, and the same file remains on the Exports page."
  end

  defp export_modal_description(%{status: "failed"}, _total_count) do
    "The background job returned an error. You can try again with the same filters or adjust the result set first."
  end

  defp export_modal_description(_export, _total_count) do
    "The job is running in the background. We’ll keep the finished download link in your export history."
  end

  defp export_product_count_label(1), do: "1 product"
  defp export_product_count_label(total_count), do: "#{total_count} products"

  defp sort_indicator(current_sort, current_dir, current_sort), do: String.upcase(current_dir)
  defp sort_indicator(_current_sort, _current_dir, _sort), do: nil
end
