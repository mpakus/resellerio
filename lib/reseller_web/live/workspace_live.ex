defmodule ResellerWeb.WorkspaceLive do
  use ResellerWeb, :live_view

  alias Ecto.Changeset
  alias Reseller.Catalog
  alias Reseller.Catalog.Product
  alias Reseller.Exports
  alias Reseller.Imports
  alias Reseller.Media
  alias Reseller.Media.Storage

  @product_filters [
    {"All", "all"},
    {"Draft", "draft"},
    {"Uploading", "uploading"},
    {"Processing", "processing"},
    {"Review", "review"},
    {"Ready", "ready"},
    {"Sold", "sold"},
    {"Archived", "archived"}
  ]

  @image_upload_accept ~w(.jpg .jpeg .png .webp)
  @zip_upload_accept ~w(.zip)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:product_images,
       accept: @image_upload_accept,
       max_entries: 5,
       max_file_size: 25_000_000
     )
     |> allow_upload(:import_archive,
       accept: @zip_upload_accept,
       max_entries: 1,
       max_file_size: 50_000_000
     )
     |> assign(
       page_title: "Workspace",
       current_scope: nil,
       section_key: :dashboard,
       workspace_nav: [],
       stats: [],
       products: [],
       visible_products: [],
       listing_rows: [],
       exports: [],
       imports: [],
       selected_product: nil,
       selected_product_id: nil,
       product_filter: "all",
       current_params: %{},
       current_url: nil,
       product_form: build_new_product_form(),
       product_edit_form: build_product_edit_form(nil)
     )}
  end

  @impl true
  def handle_params(params, uri, socket) do
    {:noreply, assign_workspace(socket, params, uri)}
  end

  @impl true
  def handle_event("validate_product", %{"product" => product_params}, socket) do
    form =
      product_params
      |> build_new_product_changeset()
      |> Map.put(:action, :validate)
      |> to_form(as: :product)

    {:noreply, assign(socket, :product_form, form)}
  end

  def handle_event("create_product", %{"product" => product_params}, socket) do
    upload_entries = socket.assigns.uploads.product_images.entries
    upload_specs = build_upload_specs(upload_entries)

    case Catalog.create_product_for_user(
           socket.assigns.current_user,
           product_params,
           upload_specs
         ) do
      {:ok, %{product: product, upload_bundle: upload_bundle}} ->
        case upload_and_finalize_product(socket, product, upload_bundle.images) do
          {:ok, finalized_product} ->
            {:noreply,
             socket
             |> put_flash(:info, "Product created from the web workspace.")
             |> push_patch(
               to:
                 products_path(%{
                   "status" => socket.assigns.product_filter,
                   "product_id" => finalized_product.id
                 })
             )}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "Product was created, but uploads failed: #{format_reason(reason)}"
             )
             |> push_patch(
               to:
                 products_path(%{
                   "status" => socket.assigns.product_filter,
                   "product_id" => product.id
                 })
             )}
        end

      {:error, %Changeset{} = changeset} ->
        {:noreply,
         assign(socket, :product_form, to_form(%{changeset | action: :validate}, as: :product))}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not create product: #{format_reason(reason)}")}
    end
  end

  def handle_event("validate_product_edit", %{"product_update" => product_params}, socket) do
    form =
      socket.assigns.selected_product
      |> build_product_edit_changeset(product_params)
      |> Map.put(:action, :validate)
      |> to_form(as: :product_update)

    {:noreply, assign(socket, :product_edit_form, form)}
  end

  def handle_event("save_product_edit", %{"product_update" => product_params}, socket) do
    case socket.assigns.selected_product do
      nil ->
        {:noreply, put_flash(socket, :error, "Choose a product before saving changes.")}

      product ->
        case Catalog.update_product_for_user(
               socket.assigns.current_user,
               product.id,
               product_params
             ) do
          {:ok, _updated_product} ->
            {:noreply,
             socket
             |> refresh_workspace()
             |> put_flash(:info, "Product details updated.")}

          {:error, %Changeset{} = changeset} ->
            {:noreply,
             assign(
               socket,
               :product_edit_form,
               to_form(%{changeset | action: :validate}, as: :product_update)
             )}

          {:error, reason} ->
            {:noreply,
             put_flash(socket, :error, "Could not update product: #{format_reason(reason)}")}
        end
    end
  end

  def handle_event("mark_sold", %{"id" => product_id}, socket) do
    {:noreply,
     mutate_product(
       socket,
       product_id,
       "Product marked as sold.",
       &Catalog.mark_product_sold_for_user/2
     )}
  end

  def handle_event("archive_product", %{"id" => product_id}, socket) do
    {:noreply,
     mutate_product(socket, product_id, "Product archived.", &Catalog.archive_product_for_user/2)}
  end

  def handle_event("restore_product", %{"id" => product_id}, socket) do
    {:noreply,
     mutate_product(
       socket,
       product_id,
       "Product restored.",
       &Catalog.unarchive_product_for_user/2
     )}
  end

  def handle_event("delete_product", %{"id" => product_id}, socket) do
    case Catalog.delete_product_for_user(socket.assigns.current_user, parse_integer(product_id)) do
      {:ok, _product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product deleted.")
         |> push_patch(to: products_path(%{"status" => socket.assigns.product_filter}))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Product not found.")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not delete product: #{format_reason(reason)}")}
    end
  end

  def handle_event("request_export", _params, socket) do
    case Exports.request_export_for_user(socket.assigns.current_user) do
      {:ok, _export} ->
        {:noreply,
         socket
         |> refresh_workspace()
         |> put_flash(:info, "Export requested from the web workspace.")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not request export: #{format_reason(reason)}")}
    end
  end

  def handle_event("run_import", _params, socket) do
    case consume_import_upload(socket) do
      {:ok, attrs} ->
        case Imports.request_import_for_user(socket.assigns.current_user, attrs) do
          {:ok, _import_record} ->
            {:noreply,
             socket
             |> refresh_workspace()
             |> put_flash(:info, "Import started from the web workspace.")}

          {:error, %Changeset{} = changeset} ->
            {:noreply,
             put_flash(socket, :error, "Import is invalid: #{inspect(changeset.errors)}")}

          {:error, reason} ->
            {:noreply,
             put_flash(socket, :error, "Could not start import: #{format_reason(reason)}")}
        end

      {:error, :missing_upload} ->
        {:noreply, put_flash(socket, :error, "Choose a ZIP archive before starting an import.")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not read import archive: #{format_reason(reason)}")}
    end
  end

  def handle_event("cancel-product-image", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :product_images, ref)}
  end

  def handle_event("cancel-import-archive", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :import_archive, ref)}
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
              Manage products, uploads, exports, and imports directly from the browser.
            </p>
            <div class="mt-5 flex flex-wrap gap-2">
              <.link patch={~p"/app/products"} class="btn btn-primary btn-sm rounded-full">
                + Add product
              </.link>
              <.link patch={~p"/app/exports"} class="btn btn-outline btn-sm rounded-full">
                Exports & imports
              </.link>
            </div>
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
                      Product intake
                    </p>
                    <p class="mt-2 text-2xl font-semibold tracking-[-0.03em]">
                      New inventory from the browser
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
                      <span class={status_badge_classes(product.status)}>{product.status}</span>
                    </div>
                  </div>
                  <p :if={@products == []} class="text-sm text-base-content/60">
                    No products yet. Open the products screen to create one with photos.
                  </p>
                </div>
              </article>

              <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Quick actions</p>
                <div class="mt-5 grid gap-3 sm:grid-cols-2">
                  <.link
                    patch={~p"/app/products"}
                    class="rounded-2xl border border-base-300 bg-base-50 px-4 py-4 transition hover:border-primary/40 hover:bg-base-200/60"
                  >
                    <p class="text-sm font-semibold">Create product</p>
                    <p class="mt-2 text-sm text-base-content/65">
                      Upload up to five photos and create the record from the web.
                    </p>
                  </.link>
                  <.link
                    patch={~p"/app/exports"}
                    class="rounded-2xl border border-base-300 bg-base-50 px-4 py-4 transition hover:border-primary/40 hover:bg-base-200/60"
                  >
                    <p class="text-sm font-semibold">Request export</p>
                    <p class="mt-2 text-sm text-base-content/65">
                      Generate a reseller ZIP archive without leaving the dashboard.
                    </p>
                  </.link>
                </div>
              </article>
            </section>
          <% :products -> %>
            <section id="workspace-products" class="grid gap-4 xl:grid-cols-[1.15fr_0.85fr]">
              <div class="grid gap-4">
                <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
                  <div class="flex flex-wrap items-center justify-between gap-4">
                    <div>
                      <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">
                        Inventory
                      </p>
                      <p class="mt-2 text-2xl font-semibold tracking-[-0.03em]">
                        Catalog with status filters
                      </p>
                    </div>
                    <a href="#new-product-form" class="btn btn-primary btn-sm rounded-full">
                      + New product
                    </a>
                  </div>

                  <div class="mt-5 flex flex-wrap gap-2" id="product-filters">
                    <.link
                      :for={{label, value} <- @product_filters}
                      patch={
                        products_path(%{"status" => value, "product_id" => @selected_product_id})
                      }
                      class={[
                        "rounded-full border px-4 py-2 text-sm transition",
                        @product_filter == value &&
                          "border-primary bg-primary text-primary-content",
                        @product_filter != value &&
                          "border-base-300 bg-base-200/60 text-base-content/70 hover:border-primary/35"
                      ]}
                    >
                      {label}
                    </.link>
                  </div>
                </article>

                <article class="overflow-hidden rounded-[1.75rem] border border-base-300 bg-base-100">
                  <table class="table table-zebra" id="workspace-products-table">
                    <thead>
                      <tr>
                        <th>Product</th>
                        <th>Status</th>
                        <th>Price</th>
                        <th>Updated</th>
                        <th></th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr
                        :for={product <- @visible_products}
                        class={[@selected_product_id == product.id && "bg-primary/5"]}
                      >
                        <td>
                          <div class="font-semibold">{product.title || "Untitled product"}</div>
                          <div class="text-xs uppercase tracking-[0.2em] text-base-content/50">
                            {product.brand || "No brand"} · {product.category || "No category"}
                          </div>
                        </td>
                        <td>
                          <span class={status_badge_classes(product.status)}>{product.status}</span>
                        </td>
                        <td>{decimal_to_string(product.price) || "—"}</td>
                        <td>{format_datetime(product.updated_at)}</td>
                        <td class="text-right">
                          <.link
                            patch={
                              products_path(%{
                                "status" => @product_filter,
                                "product_id" => product.id
                              })
                            }
                            class="btn btn-ghost btn-xs rounded-full"
                          >
                            Review
                          </.link>
                        </td>
                      </tr>
                      <tr :if={@visible_products == []}>
                        <td colspan="5" class="text-sm text-base-content/60">
                          No products found for the current filter.
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </article>
              </div>

              <div class="grid gap-4">
                <article
                  id="new-product-intake"
                  class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6"
                >
                  <.header>
                    Create product
                    <:subtitle>
                      Add details, attach up to five photos, and kick off the backend pipeline.
                    </:subtitle>
                  </.header>

                  <.form
                    for={@product_form}
                    id="new-product-form"
                    phx-change="validate_product"
                    phx-submit="create_product"
                    class="grid gap-3"
                  >
                    <div class="grid gap-3 md:grid-cols-2">
                      <.input
                        field={@product_form[:title]}
                        label="Title"
                        placeholder="Vintage denim jacket"
                      />
                      <.input field={@product_form[:brand]} label="Brand" placeholder="Levi's" />
                      <.input
                        field={@product_form[:category]}
                        label="Category"
                        placeholder="Outerwear"
                      />
                      <.input field={@product_form[:price]} type="number" step="0.01" label="Price" />
                    </div>
                    <.input
                      field={@product_form[:notes]}
                      type="textarea"
                      rows="3"
                      label="Notes"
                      placeholder="Anything the AI should keep in mind?"
                    />

                    <div class="rounded-3xl border border-dashed border-base-300 bg-base-50 p-4">
                      <div class="flex items-center justify-between gap-4">
                        <div>
                          <p class="text-sm font-semibold">Photos</p>
                          <p class="mt-1 text-sm text-base-content/60">
                            Upload JPG, PNG, or WEBP images. The backend will create the product and image records for them.
                          </p>
                        </div>
                        <.live_file_input
                          upload={@uploads.product_images}
                          class="file-input file-input-bordered file-input-sm w-full max-w-xs"
                        />
                      </div>

                      <div :if={@uploads.product_images.entries != []} class="mt-4 space-y-2">
                        <div
                          :for={entry <- @uploads.product_images.entries}
                          class="flex items-center justify-between rounded-2xl border border-base-300 bg-base-100 px-3 py-3 text-sm"
                        >
                          <div>
                            <p class="font-medium">{entry.client_name}</p>
                            <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">
                              {entry.progress}% uploaded
                            </p>
                          </div>
                          <button
                            type="button"
                            phx-click="cancel-product-image"
                            phx-value-ref={entry.ref}
                            class="btn btn-ghost btn-xs rounded-full"
                          >
                            Remove
                          </button>
                        </div>
                      </div>

                      <p
                        :for={error <- upload_errors(@uploads.product_images)}
                        class="mt-3 text-sm text-error"
                      >
                        {error_to_string(error)}
                      </p>
                    </div>

                    <.button class="btn btn-primary rounded-full">Create product</.button>
                  </.form>
                </article>

                <article
                  id="selected-product-card"
                  class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6"
                >
                  <%= if @selected_product do %>
                    <.header>
                      {@selected_product.title || "Untitled product"}
                      <:subtitle>
                        Edit the selected product and review AI-generated metadata without leaving the web workspace.
                      </:subtitle>
                    </.header>

                    <div class="flex flex-wrap items-center gap-2">
                      <span class={status_badge_classes(@selected_product.status)}>
                        {@selected_product.status}
                      </span>
                      <span :if={@selected_product.ai_confidence} class="badge badge-outline">
                        AI {Float.round(@selected_product.ai_confidence, 2)}
                      </span>
                    </div>

                    <div
                      :if={@selected_product.images != []}
                      id="selected-product-images"
                      class="mt-5 grid gap-3 sm:grid-cols-2"
                    >
                      <div
                        :for={image <- @selected_product.images}
                        class="overflow-hidden rounded-3xl border border-base-300 bg-base-50"
                      >
                        <img
                          :if={image_url = public_image_url(image)}
                          src={image_url}
                          alt={image.original_filename || image.kind}
                          class="aspect-square w-full object-cover"
                        />
                        <div class="p-3 text-sm">
                          <p class="font-semibold">{humanize_kind(image.kind)}</p>
                          <p class="mt-1 text-xs uppercase tracking-[0.18em] text-base-content/50">
                            {image.processing_status}
                          </p>
                        </div>
                      </div>
                    </div>

                    <.form
                      for={@product_edit_form}
                      id="product-edit-form"
                      phx-change="validate_product_edit"
                      phx-submit="save_product_edit"
                      class="mt-6 grid gap-3"
                    >
                      <div class="grid gap-3 md:grid-cols-2">
                        <.input field={@product_edit_form[:title]} label="Title" />
                        <.input field={@product_edit_form[:brand]} label="Brand" />
                        <.input field={@product_edit_form[:category]} label="Category" />
                        <.input field={@product_edit_form[:condition]} label="Condition" />
                        <.input field={@product_edit_form[:color]} label="Color" />
                        <.input field={@product_edit_form[:size]} label="Size" />
                        <.input field={@product_edit_form[:material]} label="Material" />
                        <.input field={@product_edit_form[:sku]} label="SKU" />
                        <.input
                          field={@product_edit_form[:price]}
                          type="number"
                          step="0.01"
                          label="Price"
                        />
                        <.input
                          field={@product_edit_form[:cost]}
                          type="number"
                          step="0.01"
                          label="Cost"
                        />
                      </div>
                      <.input
                        field={@product_edit_form[:notes]}
                        type="textarea"
                        rows="3"
                        label="Notes"
                      />

                      <div class="flex flex-wrap gap-2">
                        <.button class="btn btn-primary rounded-full">Save changes</.button>
                        <button
                          :if={@selected_product.status != "sold"}
                          type="button"
                          phx-click="mark_sold"
                          phx-value-id={@selected_product.id}
                          class="btn btn-outline btn-sm rounded-full"
                        >
                          Mark sold
                        </button>
                        <button
                          :if={@selected_product.status != "archived"}
                          type="button"
                          phx-click="archive_product"
                          phx-value-id={@selected_product.id}
                          class="btn btn-outline btn-sm rounded-full"
                        >
                          Archive
                        </button>
                        <button
                          :if={@selected_product.status == "archived"}
                          type="button"
                          phx-click="restore_product"
                          phx-value-id={@selected_product.id}
                          class="btn btn-outline btn-sm rounded-full"
                        >
                          Restore
                        </button>
                        <button
                          type="button"
                          phx-click="delete_product"
                          phx-value-id={@selected_product.id}
                          data-confirm="Delete this product?"
                          class="btn btn-ghost btn-sm rounded-full text-error"
                        >
                          Delete
                        </button>
                      </div>
                    </.form>

                    <div class="mt-6 grid gap-4">
                      <div class="rounded-3xl border border-base-300 bg-base-50 p-4">
                        <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">
                          AI summary
                        </p>
                        <p class="mt-2 text-sm leading-6 text-base-content/75">
                          {@selected_product.ai_summary || "No AI summary has been generated yet."}
                        </p>
                      </div>

                      <div
                        :if={@selected_product.description_draft}
                        class="rounded-3xl border border-base-300 bg-base-50 p-4"
                      >
                        <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">
                          Description draft
                        </p>
                        <p class="mt-2 text-sm font-semibold">
                          {@selected_product.description_draft.suggested_title}
                        </p>
                        <p class="mt-2 text-sm leading-6 text-base-content/75">
                          {@selected_product.description_draft.short_description}
                        </p>
                      </div>

                      <div
                        :if={@selected_product.price_research}
                        class="rounded-3xl border border-base-300 bg-base-50 p-4"
                      >
                        <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">
                          Price research
                        </p>
                        <p class="mt-2 text-sm text-base-content/75">
                          Median suggestion:
                          <span class="font-semibold">
                            {decimal_to_string(
                              @selected_product.price_research.suggested_median_price
                            ) || "—"}
                          </span>
                        </p>
                        <p class="mt-2 text-sm leading-6 text-base-content/75">
                          {@selected_product.price_research.rationale_summary}
                        </p>
                      </div>

                      <div
                        :if={@selected_product.marketplace_listings != []}
                        class="rounded-3xl border border-base-300 bg-base-50 p-4"
                      >
                        <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">
                          Marketplace listings
                        </p>
                        <div class="mt-3 space-y-3">
                          <div :for={listing <- @selected_product.marketplace_listings}>
                            <p class="text-sm font-semibold">
                              {String.upcase(listing.marketplace)} · {listing.generated_title}
                            </p>
                            <p class="mt-1 text-sm leading-6 text-base-content/75">
                              {listing.generated_description}
                            </p>
                          </div>
                        </div>
                      </div>

                      <div
                        :if={@selected_product.processing_runs != []}
                        class="rounded-3xl border border-base-300 bg-base-50 p-4"
                      >
                        <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">
                          Processing runs
                        </p>
                        <div class="mt-3 space-y-2 text-sm">
                          <div :for={run <- Enum.take(@selected_product.processing_runs, 3)}>
                            <p class="font-semibold">
                              {run.status} · {run.step}
                            </p>
                            <p class="text-base-content/60">{format_datetime(run.inserted_at)}</p>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% else %>
                    <.header>
                      Product details
                      <:subtitle>
                        Pick a product from the list to edit details, review AI output, or update lifecycle state.
                      </:subtitle>
                    </.header>
                    <p class="text-sm leading-6 text-base-content/65">
                      The selected product panel becomes your web control center for edits, AI review, and lifecycle actions.
                    </p>
                  <% end %>
                </article>
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
            <section id="workspace-exports" class="grid gap-4 xl:grid-cols-[0.9fr_1.1fr]">
              <div class="grid gap-4">
                <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
                  <.header>
                    Export catalog
                    <:subtitle>
                      Generate the reseller ZIP archive directly from the web workspace.
                    </:subtitle>
                    <:actions>
                      <button
                        id="request-export-button"
                        type="button"
                        phx-click="request_export"
                        class="btn btn-primary btn-sm rounded-full"
                      >
                        Request export
                      </button>
                    </:actions>
                  </.header>
                  <p class="text-sm leading-6 text-base-content/70">
                    The export worker packages `index.json` plus images into a ZIP archive and stores it for download.
                  </p>
                </article>

                <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
                  <.header>
                    Import archive
                    <:subtitle>
                      Upload a reseller ZIP to recreate products, images, and generated AI metadata.
                    </:subtitle>
                  </.header>

                  <.form
                    for={to_form(%{}, as: :import)}
                    id="import-archive-form"
                    phx-submit="run_import"
                  >
                    <div class="rounded-3xl border border-dashed border-base-300 bg-base-50 p-4">
                      <div class="flex items-center justify-between gap-4">
                        <div>
                          <p class="text-sm font-semibold">ZIP archive</p>
                          <p class="mt-1 text-sm text-base-content/60">
                            Upload one `.zip` file exported from Reseller.
                          </p>
                        </div>
                        <.live_file_input
                          upload={@uploads.import_archive}
                          class="file-input file-input-bordered file-input-sm w-full max-w-xs"
                        />
                      </div>

                      <div :if={@uploads.import_archive.entries != []} class="mt-4 space-y-2">
                        <div
                          :for={entry <- @uploads.import_archive.entries}
                          class="flex items-center justify-between rounded-2xl border border-base-300 bg-base-100 px-3 py-3 text-sm"
                        >
                          <div>
                            <p class="font-medium">{entry.client_name}</p>
                            <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">
                              {entry.progress}% uploaded
                            </p>
                          </div>
                          <button
                            type="button"
                            phx-click="cancel-import-archive"
                            phx-value-ref={entry.ref}
                            class="btn btn-ghost btn-xs rounded-full"
                          >
                            Remove
                          </button>
                        </div>
                      </div>

                      <p
                        :for={error <- upload_errors(@uploads.import_archive)}
                        class="mt-3 text-sm text-error"
                      >
                        {error_to_string(error)}
                      </p>
                    </div>

                    <.button class="btn btn-outline mt-4 rounded-full">Start import</.button>
                  </.form>
                </article>
              </div>

              <div class="grid gap-4">
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
                          <p :if={export.completed_at} class="mt-1 text-sm text-base-content/60">
                            Completed {format_datetime(export.completed_at)}
                          </p>
                        </div>
                        <div class="flex flex-col items-end gap-2">
                          <span class={status_badge_classes(export.status)}>{export.status}</span>
                          <a
                            :if={download_url = export_download_url(export)}
                            href={download_url}
                            class="btn btn-ghost btn-xs rounded-full"
                            target="_blank"
                            rel="noopener noreferrer"
                          >
                            Download
                          </a>
                        </div>
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
                          <p class="mt-1 text-sm text-base-content/60">
                            {import_row.imported_products} imported · {import_row.failed_products} failed
                          </p>
                        </div>
                        <span class={status_badge_classes(import_row.status)}>
                          {import_row.status}
                        </span>
                      </div>
                    </div>
                    <p :if={@imports == []} class="text-sm text-base-content/60">No imports yet.</p>
                  </div>
                </article>
              </div>
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
                  <li>
                    The products and exports screens now cover the main backend workflows on the web.
                  </li>
                </ul>
              </article>
            </section>
        <% end %>
      </section>
    </Layouts.app_shell>
    """
  end

  defp assign_workspace(socket, params, uri) do
    section_key = socket.assigns.live_action || :dashboard
    current_user = socket.assigns.current_user
    products = Catalog.list_products_for_user(current_user)
    product_filter = normalize_product_filter(Map.get(params, "status"))
    visible_products = filter_products(products, product_filter)
    selected_product = select_product(products, visible_products, Map.get(params, "product_id"))
    exports = Exports.list_exports_for_user(current_user)
    imports = Imports.list_imports_for_user(current_user)

    assign(socket,
      section_key: section_key,
      page_title: page_title(section_key),
      workspace_nav: workspace_nav(section_key),
      products: products,
      visible_products: visible_products,
      selected_product: selected_product,
      selected_product_id: selected_product && selected_product.id,
      product_filter: product_filter,
      product_filters: @product_filters,
      listing_rows: listing_rows(products),
      exports: exports,
      imports: imports,
      stats: dashboard_stats(products, exports, imports),
      product_form: build_new_product_form(),
      product_edit_form: build_product_edit_form(selected_product),
      current_params: params,
      current_url: uri
    )
  end

  defp refresh_workspace(socket, overrides \\ %{}) do
    params = Map.merge(socket.assigns.current_params || %{}, overrides)
    assign_workspace(socket, params, socket.assigns.current_url)
  end

  defp build_upload_specs(entries) do
    entries
    |> Enum.with_index(1)
    |> Enum.map(fn {entry, index} ->
      %{
        "filename" => entry.client_name,
        "content_type" => entry.client_type,
        "byte_size" => entry.client_size,
        "position" => index
      }
    end)
  end

  defp upload_and_finalize_product(socket, product, images) do
    case upload_product_entries(socket, images) do
      {:ok, []} ->
        {:ok, product}

      {:ok, uploaded_entries} ->
        case Catalog.finalize_product_uploads_for_user(
               socket.assigns.current_user,
               product.id,
               uploaded_entries
             ) do
          {:ok, %{product: finalized_product}} -> {:ok, finalized_product}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp upload_product_entries(_socket, []), do: {:ok, []}

  defp upload_product_entries(socket, images) do
    image_by_ref =
      socket.assigns.uploads.product_images.entries
      |> Enum.zip(images)
      |> Map.new(fn {entry, image} -> {entry.ref, image} end)

    results =
      consume_uploaded_entries(socket, :product_images, fn %{path: path}, entry ->
        image = Map.fetch!(image_by_ref, entry.ref)

        case File.read(path) do
          {:ok, body} ->
            case Storage.upload_object(image.storage_key, body, content_type: image.content_type) do
              {:ok, _upload} ->
                {:ok,
                 {:ok,
                  %{
                    "id" => image.id,
                    "byte_size" => byte_size(body),
                    "checksum" => checksum(body)
                  }}}

              {:error, reason} ->
                {:ok, {:error, reason}}
            end

          {:error, reason} ->
            {:ok, {:error, reason}}
        end
      end)

    case Enum.find(results, &match?({:error, _reason}, &1)) do
      nil ->
        {:ok, Enum.map(results, fn {:ok, uploaded_entry} -> uploaded_entry end)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp consume_import_upload(socket) do
    case socket.assigns.uploads.import_archive.entries do
      [] ->
        {:error, :missing_upload}

      _entries ->
        case consume_uploaded_entries(socket, :import_archive, fn %{path: path}, entry ->
               case File.read(path) do
                 {:ok, body} ->
                   {:ok,
                    {:ok,
                     %{
                       "filename" => entry.client_name,
                       "archive_base64" => Base.encode64(body)
                     }}}

                 {:error, reason} ->
                   {:ok, {:error, reason}}
               end
             end) do
          [{:ok, attrs}] ->
            {:ok, attrs}

          [{:error, reason}] ->
            {:error, reason}

          _other ->
            {:error, :missing_upload}
        end
    end
  end

  defp mutate_product(socket, product_id, success_message, action_fun) do
    current_user = socket.assigns.current_user
    product_id = parse_integer(product_id)

    case action_fun.(current_user, product_id) do
      {:ok, _product} ->
        socket
        |> refresh_workspace()
        |> put_flash(:info, success_message)

      {:error, :not_found} ->
        put_flash(socket, :error, "Product not found.")

      {:error, reason} ->
        put_flash(socket, :error, "Could not update product: #{format_reason(reason)}")
    end
  end

  defp build_new_product_form(attrs \\ %{}) do
    attrs
    |> build_new_product_changeset()
    |> to_form(as: :product)
  end

  defp build_new_product_changeset(attrs) do
    %Product{}
    |> Product.create_changeset(Map.merge(%{"status" => "draft", "source" => "manual"}, attrs))
  end

  defp build_product_edit_form(nil), do: to_form(%{}, as: :product_update)

  defp build_product_edit_form(product) do
    product
    |> build_product_edit_changeset(%{})
    |> to_form(as: :product_update)
  end

  defp build_product_edit_changeset(nil, attrs), do: build_new_product_changeset(attrs)
  defp build_product_edit_changeset(product, attrs), do: Product.update_changeset(product, attrs)

  defp normalize_product_filter(filter)
       when filter in ~w(all draft uploading processing review ready sold archived),
       do: filter

  defp normalize_product_filter(_filter), do: "all"

  defp filter_products(products, "all"), do: products
  defp filter_products(products, filter), do: Enum.filter(products, &(&1.status == filter))

  defp select_product(products, visible_products, product_id_param) do
    case parse_integer(product_id_param) do
      nil ->
        List.first(visible_products)

      product_id ->
        Enum.find(products, &(&1.id == product_id)) || List.first(visible_products)
    end
  end

  defp parse_integer(nil), do: nil
  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp parse_integer(_value), do: nil

  defp checksum(binary), do: Base.encode16(:crypto.hash(:sha256, binary), case: :lower)

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
  defp section_heading(:products), do: "Create, upload, and manage inventory."
  defp section_heading(:listings), do: "See marketplace-ready copy in one place."
  defp section_heading(:exports), do: "Run archive exports and imports from the web."
  defp section_heading(:settings), do: "Manage your workspace defaults."
  defp section_heading(_section), do: "Your reseller workspace is ready."

  defp section_description(:dashboard) do
    "The dashboard now links straight into the web workflows for product intake and archive generation."
  end

  defp section_description(:products) do
    "The browser workspace now creates products, uploads photos, edits metadata, and drives lifecycle actions without falling back to the API."
  end

  defp section_description(:listings) do
    "Marketplace listings generated by the AI pipeline are grouped here so you can review marketplace-specific output quickly."
  end

  defp section_description(:exports) do
    "Exports and imports are no longer API-only. Request archive jobs and upload ZIP imports directly from this web screen."
  end

  defp section_description(:settings) do
    "Settings is now a real workspace stop and will grow into account, passkey, and default-behavior controls."
  end

  defp section_description(_section) do
    "Protected browser session is active and the reseller workspace now covers core operational flows."
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

  defp products_path(params) do
    build_path("/app/products", params)
  end

  defp build_path(base_path, params) do
    query =
      params
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" or value == "all" end)
      |> Enum.into(%{})
      |> URI.encode_query()

    if query == "", do: base_path, else: base_path <> "?" <> query
  end

  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)

  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")

  defp public_image_url(image) do
    case Media.public_url_for_image(image) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  defp export_download_url(%{storage_key: nil}), do: nil

  defp export_download_url(export) do
    case Media.public_url_for_storage_key(export.storage_key) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  defp humanize_kind(kind) when is_binary(kind) do
    kind
    |> String.replace("_", " ")
    |> Phoenix.Naming.humanize()
  end

  defp humanize_kind(_kind), do: "Image"

  defp status_badge_classes(status) do
    [
      "badge border-0 capitalize",
      case status do
        "ready" -> "bg-success/15 text-success"
        "review" -> "bg-warning/20 text-warning"
        "processing" -> "bg-info/15 text-info"
        "uploading" -> "bg-info/15 text-info"
        "sold" -> "bg-neutral text-neutral-content"
        "archived" -> "bg-base-300 text-base-content/70"
        "completed" -> "bg-success/15 text-success"
        "running" -> "bg-info/15 text-info"
        "failed" -> "bg-error/15 text-error"
        _other -> "bg-base-200 text-base-content/75"
      end
    ]
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "File type is not accepted"
  defp error_to_string(other), do: inspect(other)

  defp format_reason(%Changeset{} = changeset), do: inspect(changeset.errors)
  defp format_reason(reason), do: inspect(reason)
end
