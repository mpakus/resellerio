defmodule ResellerWeb.WorkspaceLive do
  use ResellerWeb, :live_view

  alias Ecto.Changeset
  alias Reseller.Accounts
  alias Reseller.Catalog
  alias Reseller.Exports
  alias Reseller.Imports
  alias Reseller.Marketplaces
  alias Reseller.Storefronts
  alias Reseller.Storefronts.StorefrontPage
  alias Reseller.Storefronts.ThemePresets
  alias ResellerWeb.WorkspaceNavigation

  @zip_upload_accept ~w(.zip)
  @image_upload_accept ~w(.jpg .jpeg .png .webp)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Exports.subscribe(socket.assigns.current_user)
    end

    {:ok,
     socket
     |> allow_upload(:import_archive,
       accept: @zip_upload_accept,
       max_entries: 1,
       max_file_size: 50_000_000
     )
     |> allow_upload(:storefront_logo,
       accept: @image_upload_accept,
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true,
       progress: &handle_storefront_logo_progress/3
     )
     |> allow_upload(:storefront_header,
       accept: @image_upload_accept,
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true,
       progress: &handle_storefront_header_progress/3
     )
     |> assign(
       page_title: ResellerWeb.PageTitle.build("Dashboard", "Workspace"),
       section_key: :dashboard,
       workspace_nav: [],
       stats: [],
       products: [],
       exports: [],
       imports: [],
       marketplace_form: to_form(%{}, as: :settings),
       supported_marketplaces: [],
       selected_marketplaces: [],
       storefront: nil,
       storefront_form: to_form(%{}, as: :storefront),
       storefront_logo_asset: nil,
       storefront_header_asset: nil,
       storefront_pages: [],
       theme_presets: ThemePresets.all(),
       show_all_themes?: false,
       show_storefront_page_modal?: false,
       editing_storefront_page: nil,
       storefront_page_slug_locked: false,
       storefront_page_label_locked: false,
       storefront_page_form: to_form(%{}, as: :storefront_page),
       current_params: %{},
       current_url: nil
     )}
  end

  @impl true
  def handle_params(params, uri, socket) do
    {:noreply, assign_workspace(socket, params, uri)}
  end

  @impl true
  def handle_info({:export_updated, _export}, socket) do
    {:noreply, refresh_workspace(socket)}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("sync_import_upload", _params, socket) do
    {:noreply, clear_flash(socket, :error)}
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

  def handle_event("cancel-import-archive", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :import_archive, ref)}
  end

  def handle_event("rerun_export", %{"id" => export_id}, socket) do
    case Exports.retry_export_for_user(socket.assigns.current_user, export_id) do
      {:ok, export} ->
        {:noreply,
         socket
         |> refresh_workspace()
         |> put_flash(:info, "Export restarted as job ##{export.id}.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Export not found.")}

      {:error, :not_retryable} ->
        {:noreply,
         put_flash(socket, :error, "Only stalled exports can be re-run from this screen.")}

      {:error, :no_products} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "No matching products are available for that stalled export anymore."
         )}

      {:error, %Changeset{} = changeset} ->
        {:noreply,
         put_flash(socket, :error, "Could not restart export: #{inspect(changeset.errors)}")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not restart export: #{format_reason(reason)}")}
    end
  end

  def handle_event("save_marketplaces", params, socket) do
    marketplace_params =
      params
      |> Map.get("settings", %{})
      |> ensure_selected_marketplaces_param()

    case Accounts.update_user_marketplace_settings(
           socket.assigns.current_user,
           marketplace_params
         ) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> refresh_workspace()
         |> put_flash(:info, "Marketplace defaults updated for future processing runs.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply,
         assign(socket,
           marketplace_form: to_form(%{changeset | action: :validate}, as: :settings)
         )}
    end
  end

  def handle_event("validate_storefront", %{"storefront" => storefront_params}, socket) do
    storefront_form =
      socket.assigns.storefront
      |> Storefronts.change_storefront(storefront_params)
      |> Map.put(:action, :validate)
      |> to_form(as: :storefront)

    {:noreply, assign(socket, storefront_form: storefront_form)}
  end

  def handle_event("save_storefront", %{"storefront" => storefront_params}, socket) do
    case Storefronts.upsert_storefront_for_user(socket.assigns.current_user, storefront_params) do
      {:ok, _storefront} ->
        {:noreply,
         socket
         |> refresh_workspace()
         |> put_flash(:info, "Storefront settings saved.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply,
         assign(socket,
           storefront_form: to_form(%{changeset | action: :validate}, as: :storefront)
         )}
    end
  end

  def handle_event("noop", _params, socket), do: {:noreply, socket}

  def handle_event("toggle_all_themes", _params, socket) do
    {:noreply, assign(socket, show_all_themes?: !socket.assigns.show_all_themes?)}
  end

  def handle_event("cancel-storefront-logo", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :storefront_logo, ref)}
  end

  def handle_event("cancel-storefront-header", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :storefront_header, ref)}
  end

  def handle_event("upload_storefront_logo", _params, socket) do
    {:noreply, upload_storefront_asset(socket, :storefront_logo, "logo")}
  end

  def handle_event("upload_storefront_header", _params, socket) do
    {:noreply, upload_storefront_asset(socket, :storefront_header, "header")}
  end

  defp handle_storefront_logo_progress(:storefront_logo, entry, socket) do
    if entry.done? do
      {:noreply, consume_storefront_asset_entry(socket, entry, "logo")}
    else
      {:noreply, socket}
    end
  end

  defp handle_storefront_header_progress(:storefront_header, entry, socket) do
    if entry.done? do
      {:noreply, consume_storefront_asset_entry(socket, entry, "header")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_storefront_asset", %{"kind" => kind}, socket) do
    case Storefronts.delete_storefront_asset_for_user(socket.assigns.current_user, kind) do
      {:ok, _asset} ->
        {:noreply,
         socket
         |> refresh_workspace()
         |> put_flash(:info, "#{storefront_asset_label(kind)} removed.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "#{storefront_asset_label(kind)} not found.")}
    end
  end

  def handle_event("open_storefront_page_modal", _params, socket) do
    if socket.assigns.storefront.id do
      {:noreply,
       assign(socket,
         show_storefront_page_modal?: true,
         editing_storefront_page: nil,
         storefront_page_slug_locked: false,
         storefront_page_label_locked: false,
         storefront_page_form: build_storefront_page_form(%StorefrontPage{})
       )}
    else
      {:noreply,
       put_flash(socket, :error, "Save storefront details before creating public pages.")}
    end
  end

  def handle_event("open_edit_storefront_page_modal", %{"id" => page_id}, socket) do
    case Storefronts.get_storefront_page_for_user(socket.assigns.current_user, page_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Storefront page not found.")}

      page ->
        {:noreply,
         assign(socket,
           show_storefront_page_modal?: true,
           editing_storefront_page: page,
           storefront_page_slug_locked: true,
           storefront_page_label_locked: true,
           storefront_page_form: build_storefront_page_form(page)
         )}
    end
  end

  def handle_event("close_storefront_page_modal", _params, socket) do
    {:noreply, reset_storefront_page_modal(socket)}
  end

  def handle_event("lock_storefront_page_slug", _params, socket),
    do: {:noreply, assign(socket, storefront_page_slug_locked: true)}

  def handle_event("lock_storefront_page_label", _params, socket),
    do: {:noreply, assign(socket, storefront_page_label_locked: true)}

  def handle_event("validate_storefront_page", %{"storefront_page" => page_params}, socket) do
    page =
      socket.assigns.editing_storefront_page ||
        %StorefrontPage{storefront_id: socket.assigns.storefront.id}

    page_params = maybe_strip_derived_slug_and_label(page, page_params, socket)

    storefront_page_form =
      page
      |> Storefronts.change_storefront_page(page_params)
      |> Map.put(:action, :validate)
      |> to_form(as: :storefront_page)

    {:noreply, assign(socket, storefront_page_form: storefront_page_form)}
  end

  def handle_event("create_storefront_page", %{"storefront_page" => page_params}, socket) do
    case Storefronts.create_storefront_page_for_user(socket.assigns.current_user, page_params) do
      {:ok, _page} ->
        {:noreply,
         socket
         |> refresh_workspace()
         |> reset_storefront_page_modal()
         |> put_flash(:info, "Storefront page created.")}

      {:error, :storefront_not_found} ->
        {:noreply,
         put_flash(socket, :error, "Save storefront details before creating public pages.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply,
         assign(socket,
           storefront_page_form: to_form(%{changeset | action: :validate}, as: :storefront_page)
         )}
    end
  end

  def handle_event("update_storefront_page", %{"storefront_page" => page_params}, socket) do
    case Storefronts.update_storefront_page_for_user(
           socket.assigns.current_user,
           socket.assigns.editing_storefront_page.id,
           page_params
         ) do
      {:ok, _page} ->
        {:noreply,
         socket
         |> refresh_workspace()
         |> reset_storefront_page_modal()
         |> put_flash(:info, "Storefront page updated.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Storefront page not found.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply,
         assign(socket,
           storefront_page_form: to_form(%{changeset | action: :validate}, as: :storefront_page)
         )}
    end
  end

  def handle_event("delete_storefront_page", %{"id" => page_id}, socket) do
    case Storefronts.delete_storefront_page_for_user(socket.assigns.current_user, page_id) do
      {:ok, _page} ->
        {:noreply,
         socket
         |> refresh_workspace()
         |> put_flash(:info, "Storefront page deleted.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Storefront page not found.")}
    end
  end

  def handle_event("move_storefront_page", %{"id" => page_id, "direction" => direction}, socket) do
    parsed_direction =
      case direction do
        "up" -> :up
        "down" -> :down
        _other -> nil
      end

    case parsed_direction &&
           Storefronts.move_storefront_page_for_user(
             socket.assigns.current_user,
             page_id,
             parsed_direction
           ) do
      {:ok, _page} ->
        {:noreply, refresh_workspace(socket)}

      {:error, :edge} ->
        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Storefront page not found.")}

      _other ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app_shell
      flash={@flash}
      current_user={@current_user}
      workspace_nav={@workspace_nav}
      nav_mode={:patch}
    >
      <section class="grid gap-8">
        <div class="grid gap-4 lg:grid-cols-[1.1fr_0.9fr] lg:items-end">
          <.section_intro
            id="workspace-heading"
            eyebrow={section_eyebrow(@section_key)}
            title={section_heading(@section_key)}
            description={section_description(@section_key)}
            title_class="reseller-display mt-4 text-5xl font-semibold tracking-[-0.04em] text-balance"
            class="gap-0"
          />

          <.surface tag="div" class="rounded-[2rem]">
            <p class="text-xs uppercase tracking-[0.3em] text-base-content/50">Current user</p>
            <p id="workspace-user-email" class="mt-4 text-2xl font-semibold tracking-[-0.03em]">
              {@current_user.email}
            </p>
            <p class="mt-2 text-sm text-base-content/65">
              Manage products, uploads, exports, and imports directly from the browser.
            </p>
            <div class="mt-5 flex flex-wrap gap-2">
              <.link navigate={~p"/app/products/new"} class="btn btn-primary btn-sm rounded-full">
                + Add product
              </.link>
              <.link patch={~p"/app/exports"} class="btn btn-outline btn-sm rounded-full">
                Exports & imports
              </.link>
            </div>
          </.surface>
        </div>

        <%= case @section_key do %>
          <% :dashboard -> %>
            <section id="workspace-dashboard" class="grid gap-4 xl:grid-cols-4">
              <.metric_card
                :for={stat <- @stats}
                label={stat.label}
                value={stat.value}
                description={stat.description}
              />
            </section>

            <section class="grid gap-4 xl:grid-cols-[1.1fr_0.9fr]">
              <.surface tag="article">
                <div class="flex items-center justify-between gap-4">
                  <div>
                    <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">
                      Product intake
                    </p>
                    <p class="mt-2 text-2xl font-semibold tracking-[-0.03em]">
                      New inventory from the browser
                    </p>
                  </div>
                  <.link navigate={~p"/app/products"} class="btn btn-outline btn-sm rounded-full">
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
                      <.status_badge status={product.status} />
                    </div>
                  </div>
                  <p :if={@products == []} class="text-sm text-base-content/60">
                    No products yet. Open the products screen to create one with photos.
                  </p>
                </div>
              </.surface>

              <.surface tag="article">
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Quick actions</p>
                <div class="mt-5 grid gap-3 sm:grid-cols-2">
                  <.feature_tile
                    navigate={~p"/app/products/new"}
                    title="Create product"
                    description="Upload up to five photos and create the record from the web."
                    accent="primary"
                    class="rounded-2xl bg-base-50/95"
                  >
                    <:meta>
                      <span class="text-xs uppercase tracking-[0.2em] text-base-content/45">
                        Intake
                      </span>
                    </:meta>
                  </.feature_tile>
                  <.feature_tile
                    patch={~p"/app/exports"}
                    title="Request export"
                    description="Generate a Resellerio ZIP archive without leaving the dashboard."
                    accent="secondary"
                    class="rounded-2xl bg-base-50/95"
                  >
                    <:meta>
                      <span class="text-xs uppercase tracking-[0.2em] text-base-content/45">
                        Transfer
                      </span>
                    </:meta>
                  </.feature_tile>
                </div>
              </.surface>
            </section>
          <% :exports -> %>
            <section id="workspace-exports" class="grid gap-4 xl:grid-cols-[0.9fr_1.1fr]">
              <div class="grid gap-4">
                <.surface tag="article">
                  <.header>
                    Export history
                    <:subtitle>
                      Start archive generation from the Products page so the active search and filters are saved with the export.
                    </:subtitle>
                  </.header>
                  <p class="text-sm leading-6 text-base-content/70">
                    Each finished ZIP contains `Products.xls`, `manifest.json`, and `images/&lt;product_id&gt;/...`.
                    Use the Products table when you need a filtered export instead of a full catalog dump.
                  </p>
                  <div class="mt-4">
                    <.link navigate={~p"/app/products"} class="btn btn-outline rounded-full">
                      Open products
                    </.link>
                  </div>
                </.surface>

                <.surface tag="article">
                  <.header>
                    Import archive
                    <:subtitle>
                      Upload a Resellerio ZIP to recreate products, images, and generated AI metadata.
                    </:subtitle>
                  </.header>

                  <.form
                    for={to_form(%{}, as: :import)}
                    id="import-archive-form"
                    phx-change="sync_import_upload"
                    phx-submit="run_import"
                  >
                    <.upload_panel
                      id="import-archive-upload-panel"
                      title="ZIP archive"
                      description="Upload one `.zip` file exported from Resellerio."
                      upload={@uploads.import_archive}
                      cancel_event="cancel-import-archive"
                      errors={Enum.map(upload_errors(@uploads.import_archive), &error_to_string/1)}
                    />

                    <.button class="btn btn-outline mt-4 rounded-full">Start import</.button>
                  </.form>
                </.surface>
              </div>

              <div class="grid gap-4">
                <.surface tag="article">
                  <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Exports</p>
                  <div class="mt-5 space-y-3">
                    <.surface
                      :for={export <- @exports}
                      tag="div"
                      variant="soft"
                      padding="sm"
                    >
                      <div class="flex flex-wrap items-start justify-between gap-4">
                        <div class="min-w-0 flex-1">
                          <p class="text-sm font-semibold">{export.name}</p>
                          <p class="mt-1 text-xs uppercase tracking-[0.2em] text-base-content/50">
                            {export.file_name}
                          </p>
                          <p class="mt-2 text-sm text-base-content/60">
                            Requested {format_datetime(export.requested_at)} · {export.product_count} products
                          </p>
                          <p :if={export.completed_at} class="mt-1 text-sm text-base-content/60">
                            Completed {format_datetime(export.completed_at)}
                          </p>
                          <p
                            :if={export.error_message && export.status in ["failed", "stalled"]}
                            class={[
                              "mt-2 text-sm leading-6",
                              export.status == "failed" && "text-error",
                              export.status == "stalled" && "text-warning"
                            ]}
                          >
                            {export.error_message}
                          </p>
                          <div class="mt-3 flex flex-wrap gap-2">
                            <span
                              :for={detail <- export_filter_details(export)}
                              class="badge badge-outline rounded-full px-3 py-3 text-xs uppercase tracking-[0.16em]"
                            >
                              {detail.label}: {detail.value}
                            </span>
                          </div>
                        </div>
                        <div class="flex flex-col items-end gap-2">
                          <.status_badge status={export.status} />
                          <button
                            :if={export.status == "stalled"}
                            type="button"
                            phx-click="rerun_export"
                            phx-value-id={export.id}
                            class="btn btn-outline btn-xs rounded-full"
                          >
                            Re-run
                          </button>
                          <a
                            :if={download_url = export_download_url(export)}
                            href={download_url}
                            class="btn btn-outline btn-xs rounded-full"
                            download={export.file_name}
                            target="_blank"
                            rel="noopener noreferrer"
                          >
                            Download .zip
                          </a>
                        </div>
                      </div>
                    </.surface>
                    <p :if={@exports == []} class="text-sm text-base-content/60">No exports yet.</p>
                  </div>
                </.surface>

                <.surface tag="article">
                  <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Imports</p>
                  <div class="mt-5 space-y-3">
                    <.surface
                      :for={import_row <- @imports}
                      tag="div"
                      variant="soft"
                      padding="sm"
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
                        <.status_badge status={import_row.status} />
                      </div>
                    </.surface>
                    <p :if={@imports == []} class="text-sm text-base-content/60">No imports yet.</p>
                  </div>
                </.surface>
              </div>
            </section>
          <% :settings -> %>
            <section id="workspace-settings" class="grid gap-4 xl:grid-cols-[1.12fr_0.88fr]">
              <div class="grid gap-4">
                <.surface tag="article">
                  <.header>
                    Public storefront
                    <:subtitle>
                      Configure your public seller profile, reserved storefront path, and the preset theme visitors will see once storefront routes land.
                    </:subtitle>
                  </.header>

                  <.form
                    for={@storefront_form}
                    id="storefront-settings-form"
                    phx-change="validate_storefront"
                    phx-submit="save_storefront"
                    class="grid gap-5"
                  >
                    <div class="flex flex-wrap items-center justify-between gap-3 rounded-[1.5rem] border border-base-300 bg-base-50 px-4 py-4">
                      <div>
                        <p class="text-sm font-semibold">Storefront live switch</p>
                        <p class="mt-1 text-sm leading-6 text-base-content/65">
                          Enable this when you are ready for the public storefront to become reachable in the later routing step.
                        </p>
                      </div>
                      <label class="label cursor-pointer gap-3">
                        <input type="hidden" name="storefront[enabled]" value="false" />
                        <input
                          id="storefront-enabled"
                          type="checkbox"
                          name="storefront[enabled]"
                          value="true"
                          checked={truthy_field?(@storefront_form[:enabled].value)}
                          class="toggle toggle-primary"
                        />
                        <span class="text-sm font-medium">Enabled</span>
                      </label>
                    </div>

                    <div class="grid gap-3 md:grid-cols-2">
                      <.input field={@storefront_form[:title]} label="Storefront title" />
                      <.input field={@storefront_form[:slug]} label="Slug" />
                      <.input field={@storefront_form[:tagline]} label="Tagline" />
                      <div class="rounded-[1.5rem] border border-base-300 bg-base-50 px-4 py-4">
                        <p class="text-xs uppercase tracking-[0.2em] text-base-content/45">
                          Preview path
                        </p>
                        <a
                          id="storefront-preview-url"
                          href={storefront_root_url(@storefront_form[:slug].value)}
                          target="_blank"
                          rel="noopener noreferrer"
                          class="mt-2 flex items-center gap-2 break-all text-sm font-medium leading-6 text-base-content hover:text-primary"
                        >
                          {storefront_root_url(@storefront_form[:slug].value)}
                          <.icon name="hero-arrow-top-right-on-square" class="size-4 shrink-0" />
                        </a>
                        <p class="mt-2 text-sm leading-6 text-base-content/65">
                          Public routes are completed in SF4. This is the reserved path your storefront will use.
                        </p>
                      </div>
                    </div>

                    <.input
                      field={@storefront_form[:description]}
                      type="textarea"
                      rows="4"
                      label="Description"
                      placeholder="A short introduction, resale specialty, shipping promise, or contact expectation."
                    />

                    <div>
                      <div class="flex items-center justify-between gap-3">
                        <div>
                          <p class="text-sm font-semibold">Theme presets</p>
                          <p class="mt-1 text-sm leading-6 text-base-content/65">
                            Choose one of the curated palettes. Freeform editing is intentionally deferred.
                          </p>
                        </div>
                        <span class="badge rounded-full border border-base-300 bg-base-50 px-3 py-3 text-xs uppercase tracking-[0.16em] text-base-content/60">
                          {length(@theme_presets)} presets
                        </span>
                      </div>

                      <div
                        id="storefront-theme-picker"
                        class="mt-4 grid gap-3 lg:grid-cols-2 2xl:grid-cols-3"
                      >
                        <label
                          :for={preset <- visible_theme_presets(@theme_presets, @show_all_themes?, current_theme_id(@storefront_form))}
                          for={"storefront-theme-#{preset.id}"}
                          class="block cursor-pointer"
                        >
                          <input
                            id={"storefront-theme-#{preset.id}"}
                            type="radio"
                            name="storefront[theme_id]"
                            value={preset.id}
                            checked={current_theme_id(@storefront_form) == preset.id}
                            class="sr-only"
                          />
                          <div
                            class={
                              theme_preset_card_classes(
                                current_theme_id(@storefront_form) == preset.id
                              )
                            }
                            style={theme_preset_card_style(preset)}
                          >
                            <div class="flex items-start justify-between gap-3">
                              <div>
                                <p class="text-sm font-semibold">{preset.label}</p>
                                <p class="mt-1 text-[11px] uppercase tracking-[0.18em] opacity-70">
                                  {preset.id}
                                </p>
                              </div>
                              <span class="inline-flex gap-1">
                                <span
                                  :for={color <- theme_preview_swatches(preset)}
                                  class="size-4 rounded-full border border-white/60 shadow-sm"
                                  style={"background: #{color}"}
                                >
                                </span>
                              </span>
                            </div>

                            <div class="mt-4 overflow-hidden rounded-[1.4rem] border border-white/40 bg-white/10">
                              <div class="px-4 py-4" style={theme_preview_hero_style(preset)}>
                                <div class="max-w-[12rem]">
                                  <p class="text-[11px] uppercase tracking-[0.18em] opacity-80">
                                    Header sample
                                  </p>
                                  <p class="mt-2 text-base font-semibold">
                                    {@storefront_form[:title].value || "Your storefront"}
                                  </p>
                                  <p class="mt-1 text-xs leading-5 opacity-80">
                                    {@storefront_form[:tagline].value ||
                                      "Curated resale inventory and quick shipping."}
                                  </p>
                                </div>
                              </div>
                              <div class="grid gap-3 px-4 py-4 md:grid-cols-[auto,1fr]">
                                <div class="size-14 rounded-2xl border border-white/40 bg-white/20">
                                </div>
                                <div>
                                  <p class="text-[11px] uppercase tracking-[0.18em] opacity-70">
                                    Product card
                                  </p>
                                  <p class="mt-2 text-sm font-semibold">Vintage denim jacket</p>
                                  <p class="mt-1 text-xs leading-5 opacity-80">
                                    $84 · Ready to share
                                  </p>
                                </div>
                              </div>
                            </div>
                          </div>
                        </label>
                      </div>

                      <button
                        type="button"
                        phx-click="toggle_all_themes"
                        class="mt-3 flex items-center gap-1.5 text-sm text-base-content/60 hover:text-base-content transition"
                      >
                        <.icon
                          name={if @show_all_themes?, do: "hero-chevron-up", else: "hero-chevron-down"}
                          class="size-4"
                        />
                        {if @show_all_themes?,
                          do: "Show fewer presets",
                          else: "Show all #{length(@theme_presets)} presets"}
                      </button>
                    </div>

                    <div class="flex flex-wrap items-center justify-between gap-3">
                      <p class="text-sm leading-6 text-base-content/65">
                        Save the profile first to unlock branding uploads and public page management.
                      </p>
                      <.button class="btn btn-primary rounded-full">Save storefront</.button>
                    </div>
                  </.form>
                </.surface>

                <.surface tag="article">
                  <.header>
                    Branding assets
                    <:subtitle>
                      Upload a square logo and a wide header. These reuse the same storage pipeline as product media, but stay isolated from product images.
                    </:subtitle>
                  </.header>

                  <div class="grid gap-4 lg:grid-cols-2">
                    <div class="rounded-[1.75rem] border border-base-300 bg-base-50 px-4 py-4">
                      <div class="flex items-start justify-between gap-3">
                        <div>
                          <p class="text-sm font-semibold">Logo</p>
                          <p class="mt-1 text-sm leading-6 text-base-content/65">
                            Use a transparent PNG or square JPG for compact nav and hero branding.
                          </p>
                        </div>
                        <button
                          :if={@storefront_logo_asset}
                          type="button"
                          phx-click="delete_storefront_asset"
                          phx-value-kind="logo"
                          class="btn btn-ghost btn-xs rounded-full text-error"
                        >
                          Remove
                        </button>
                      </div>

                      <div class="mt-4 rounded-[1.5rem] border border-dashed border-base-300 bg-base-100 px-4 py-4">
                        <img
                          :if={logo_url = storefront_asset_url(@storefront_logo_asset)}
                          src={logo_url}
                          alt="Storefront logo"
                          class="mx-auto aspect-square size-36 rounded-[1.5rem] object-cover"
                        />
                        <div
                          :if={!@storefront_logo_asset}
                          class="flex aspect-square h-36 items-center justify-center rounded-[1.5rem] bg-base-200/70 text-sm text-base-content/55"
                        >
                          No logo uploaded
                        </div>
                      </div>

                      <.form
                        :if={@storefront.id}
                        for={to_form(%{}, as: :storefront_logo)}
                        id="storefront-logo-form"
                        phx-submit="upload_storefront_logo"
                        phx-change="noop"
                        class="mt-4"
                      >
                        <.upload_panel
                          id="storefront-logo-upload-panel"
                          title="Upload logo"
                          description="One JPG, PNG, or WEBP file up to 10MB."
                          upload={@uploads.storefront_logo}
                          cancel_event="cancel-storefront-logo"
                          errors={
                            Enum.map(upload_errors(@uploads.storefront_logo), &error_to_string/1)
                          }
                          input_class="file-input file-input-bordered file-input-sm w-full"
                        />
                      </.form>

                      <p :if={!@storefront.id} class="mt-4 text-sm leading-6 text-base-content/65">
                        Save the storefront profile before uploading logo assets.
                      </p>
                    </div>

                    <div class="rounded-[1.75rem] border border-base-300 bg-base-50 px-4 py-4">
                      <div class="flex items-start justify-between gap-3">
                        <div>
                          <p class="text-sm font-semibold">Header image</p>
                          <p class="mt-1 text-sm leading-6 text-base-content/65">
                            Use a wide image for the storefront hero and collection banner.
                          </p>
                        </div>
                        <button
                          :if={@storefront_header_asset}
                          type="button"
                          phx-click="delete_storefront_asset"
                          phx-value-kind="header"
                          class="btn btn-ghost btn-xs rounded-full text-error"
                        >
                          Remove
                        </button>
                      </div>

                      <div class="mt-4 rounded-[1.5rem] border border-dashed border-base-300 bg-base-100 px-4 py-4">
                        <img
                          :if={header_url = storefront_asset_url(@storefront_header_asset)}
                          src={header_url}
                          alt="Storefront header"
                          class="aspect-[16/9] w-full rounded-[1.5rem] object-cover"
                        />
                        <div
                          :if={!@storefront_header_asset}
                          class="flex aspect-[16/9] items-center justify-center rounded-[1.5rem] bg-base-200/70 text-sm text-base-content/55"
                        >
                          No header uploaded
                        </div>
                      </div>

                      <.form
                        :if={@storefront.id}
                        for={to_form(%{}, as: :storefront_header)}
                        id="storefront-header-form"
                        phx-submit="upload_storefront_header"
                        phx-change="noop"
                        class="mt-4"
                      >
                        <.upload_panel
                          id="storefront-header-upload-panel"
                          title="Upload header"
                          description="One JPG, PNG, or WEBP file up to 10MB."
                          upload={@uploads.storefront_header}
                          cancel_event="cancel-storefront-header"
                          errors={
                            Enum.map(upload_errors(@uploads.storefront_header), &error_to_string/1)
                          }
                          input_class="file-input file-input-bordered file-input-sm w-full"
                        />
                      </.form>

                      <p :if={!@storefront.id} class="mt-4 text-sm leading-6 text-base-content/65">
                        Save the storefront profile before uploading header assets.
                      </p>
                    </div>
                  </div>
                </.surface>

                <.surface tag="article">
                  <.header>
                    Storefront pages
                    <:subtitle>
                      Add public menu pages like About, Shipping, or Returns. Reordering is simple up/down movement for now.
                    </:subtitle>
                    <:actions>
                      <button
                        id="open-storefront-page-modal-button"
                        type="button"
                        phx-click="open_storefront_page_modal"
                        class="btn btn-outline btn-sm rounded-full"
                      >
                        Add page
                      </button>
                    </:actions>
                  </.header>

                  <div
                    :if={@storefront.id == nil}
                    class="rounded-[1.5rem] border border-base-300 bg-base-50 px-4 py-4 text-sm leading-6 text-base-content/68"
                  >
                    Save the storefront profile before adding custom menu pages.
                  </div>

                  <div
                    :if={@storefront.id && @storefront_pages == []}
                    class="rounded-[1.5rem] border border-dashed border-base-300 bg-base-50 px-4 py-4 text-sm leading-6 text-base-content/68"
                  >
                    No public pages yet. Add your first page to create menu destinations like About, Shipping, or Returns.
                  </div>

                  <div :if={@storefront_pages != []} id="storefront-pages-list" class="space-y-3">
                    <div
                      :for={page <- @storefront_pages}
                      id={"storefront-page-#{page.id}"}
                      class="rounded-[1.6rem] border border-base-300 bg-base-50 px-4 py-4"
                    >
                      <div class="flex flex-wrap items-start justify-between gap-3">
                        <div class="min-w-0 flex-1">
                          <div class="flex flex-wrap items-center gap-2">
                            <p class="text-sm font-semibold">{page.title}</p>
                            <span class={[
                              "badge rounded-full px-3 py-2 text-[11px] uppercase tracking-[0.16em]",
                              page.published && "badge-primary badge-outline",
                              !page.published &&
                                "badge-ghost border border-base-300 text-base-content/55"
                            ]}>
                              {if(page.published, do: "Published", else: "Draft")}
                            </span>
                          </div>
                          <p class="mt-1 text-xs uppercase tracking-[0.18em] text-base-content/45">
                            <a
                              href={storefront_page_url(@storefront, page)}
                              target="_blank"
                              rel="noopener noreferrer"
                              class="inline-flex items-center gap-1 hover:text-base-content transition-colors"
                            >
                              {storefront_page_url(@storefront, page)}
                              <.icon name="hero-arrow-top-right-on-square" class="size-3" />
                            </a>
                          </p>
                          <p class="mt-3 text-sm leading-6 text-base-content/70">
                            {truncate_copy(page.body, 140)}
                          </p>
                        </div>

                        <div class="flex flex-wrap gap-2">
                          <button
                            type="button"
                            phx-click="move_storefront_page"
                            phx-value-id={page.id}
                            phx-value-direction="up"
                            class="btn btn-ghost btn-xs rounded-full"
                          >
                            Up
                          </button>
                          <button
                            type="button"
                            phx-click="move_storefront_page"
                            phx-value-id={page.id}
                            phx-value-direction="down"
                            class="btn btn-ghost btn-xs rounded-full"
                          >
                            Down
                          </button>
                          <button
                            type="button"
                            phx-click="open_edit_storefront_page_modal"
                            phx-value-id={page.id}
                            class="btn btn-outline btn-xs rounded-full"
                          >
                            Edit
                          </button>
                          <button
                            type="button"
                            phx-click="delete_storefront_page"
                            phx-value-id={page.id}
                            data-confirm="Delete this storefront page?"
                            class="btn btn-ghost btn-xs rounded-full text-error"
                          >
                            Delete
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                </.surface>
              </div>

              <div class="grid gap-4">
                <.surface tag="article">
                  <.header>
                    Marketplace defaults
                    <:subtitle>
                      Choose which supported marketplaces should receive AI-generated listing drafts on future processing and reprocessing runs.
                    </:subtitle>
                  </.header>

                  <.form
                    for={@marketplace_form}
                    id="marketplace-settings-form"
                    phx-submit="save_marketplaces"
                  >
                    <input type="hidden" name="settings[selected_marketplaces][]" value="" />

                    <div class="mt-5 grid gap-3 sm:grid-cols-2">
                      <label
                        :for={marketplace <- @supported_marketplaces}
                        for={"marketplace-#{marketplace.id}"}
                        class={[
                          "grid grid-cols-[auto,minmax(0,1fr)] items-start gap-3 rounded-2xl border px-4 py-4 transition",
                          marketplace.id in @selected_marketplaces &&
                            "border-primary bg-primary/6 shadow-[0_12px_30px_rgba(216,123,56,0.12)]",
                          marketplace.id not in @selected_marketplaces &&
                            "border-base-300 bg-base-50 hover:border-base-400"
                        ]}
                      >
                        <input
                          id={"marketplace-#{marketplace.id}"}
                          type="checkbox"
                          name="settings[selected_marketplaces][]"
                          value={marketplace.id}
                          checked={marketplace.id in @selected_marketplaces}
                          class="checkbox checkbox-sm mt-1 rounded-md border-base-400 text-primary"
                        />
                        <div class="min-w-0">
                          <p class="text-sm font-semibold leading-5 text-base-content text-balance">
                            {marketplace.label}
                          </p>
                          <p class="mt-1 break-all text-[11px] leading-5 text-base-content/45">
                            {marketplace.id}
                          </p>
                        </div>
                      </label>
                    </div>

                    <div class="mt-5 flex flex-wrap items-center justify-between gap-3">
                      <p id="selected-marketplace-count" class="text-sm text-base-content/65">
                        {length(@selected_marketplaces)} selected
                      </p>
                      <.button class="btn btn-primary rounded-full">Save marketplaces</.button>
                    </div>
                  </.form>
                </.surface>

                <.surface tag="article">
                  <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Account</p>
                  <p class="mt-3 text-2xl font-semibold tracking-[-0.03em]">{@current_user.email}</p>
                  <p class="mt-3 text-sm leading-6 text-base-content/70">
                    These marketplace defaults affect future listing generation. Existing stored listing drafts stay attached to their products until you reprocess or remove them later.
                  </p>
                  <div class="mt-5 flex flex-wrap gap-2">
                    <span
                      :for={marketplace <- @supported_marketplaces}
                      class={[
                        "badge rounded-full px-3 py-3 text-xs uppercase tracking-[0.16em]",
                        marketplace.id in @selected_marketplaces &&
                          "badge-primary badge-outline",
                        marketplace.id not in @selected_marketplaces &&
                          "badge-ghost border border-base-300 text-base-content/55"
                      ]}
                    >
                      {marketplace.label}
                    </span>
                  </div>
                </.surface>
              </div>
            </section>
        <% end %>
      </section>

      <div
        :if={@show_storefront_page_modal?}
        id="storefront-page-modal"
        class="fixed inset-0 z-50 flex items-center justify-center px-4 py-8"
      >
        <button
          type="button"
          phx-click="close_storefront_page_modal"
          class="absolute inset-0 bg-neutral/55"
          aria-label="Close storefront page modal"
        >
        </button>

        <.surface
          tag="section"
          class="relative z-10 w-full max-w-2xl border-base-300 bg-base-100 shadow-[0_30px_90px_rgba(20,20,20,0.28)]"
        >
          <div class="flex items-start justify-between gap-4">
            <div>
              <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">
                Storefront page
              </p>
              <p class="mt-2 text-2xl font-semibold tracking-[-0.03em]">
                {storefront_page_modal_title(@editing_storefront_page)}
              </p>
              <p class="mt-2 text-sm leading-6 text-base-content/68">
                {storefront_page_modal_description(@editing_storefront_page)}
              </p>
            </div>
            <button
              type="button"
              phx-click="close_storefront_page_modal"
              class="btn btn-ghost btn-sm rounded-full"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <.form
            for={@storefront_page_form}
            id="storefront-page-form"
            phx-change="validate_storefront_page"
            phx-submit={
              if(@editing_storefront_page,
                do: "update_storefront_page",
                else: "create_storefront_page"
              )
            }
            class="mt-6 grid gap-4"
          >
            <div class="grid gap-3 md:grid-cols-2">
              <.input field={@storefront_page_form[:title]} label="Title" />
              <.input
                field={@storefront_page_form[:slug]}
                label="Slug"
                phx-blur="lock_storefront_page_slug"
              />
              <.input
                field={@storefront_page_form[:menu_label]}
                label="Menu label"
                phx-blur="lock_storefront_page_label"
              />
              <div class="rounded-[1.4rem] border border-base-300 bg-base-50 px-4 py-4">
                <label class="label cursor-pointer justify-start gap-3">
                  <input type="hidden" name="storefront_page[published]" value="false" />
                  <input
                    type="checkbox"
                    name="storefront_page[published]"
                    value="true"
                    checked={truthy_field?(@storefront_page_form[:published].value)}
                    class="checkbox checkbox-sm rounded-md border-base-400 text-primary"
                  />
                  <span class="text-sm font-medium">Published</span>
                </label>
                <p class="mt-2 text-sm leading-6 text-base-content/65">
                  Unpublished pages stay hidden from the public menu until you’re ready.
                </p>
              </div>
            </div>

            <.input
              field={@storefront_page_form[:body]}
              type="textarea"
              rows="8"
              label="Body"
              placeholder="Plain text only in v1. Paragraph breaks are preserved when rendered publicly."
            />

            <div class="flex flex-wrap gap-2">
              <button type="submit" class="btn btn-primary rounded-full">
                {if(@editing_storefront_page, do: "Save page", else: "Create page")}
              </button>
              <button
                type="button"
                phx-click="close_storefront_page_modal"
                class="btn btn-ghost rounded-full"
              >
                Cancel
              </button>
            </div>
          </.form>
        </.surface>
      </div>
    </Layouts.app_shell>
    """
  end

  defp assign_workspace(socket, params, uri) do
    section_key = socket.assigns.live_action || :dashboard
    current_user = socket.assigns.current_user
    products = Catalog.list_products_for_user(current_user)
    exports = Exports.list_exports_for_user(current_user)
    imports = Imports.list_imports_for_user(current_user)
    selected_marketplaces = Accounts.selected_marketplaces(current_user)
    storefront = Storefronts.get_or_build_storefront_for_user(current_user)

    assign(socket,
      section_key: section_key,
      page_title: page_title(section_key),
      workspace_nav:
        WorkspaceNavigation.items(section_key,
          mode: :patch,
          item_modes: %{products: :navigate}
        ),
      products: products,
      exports: exports,
      imports: imports,
      marketplace_form: build_marketplace_form(current_user, selected_marketplaces),
      supported_marketplaces: Marketplaces.catalog(),
      selected_marketplaces: selected_marketplaces,
      storefront: storefront,
      storefront_form: build_storefront_form(storefront),
      storefront_logo_asset: storefront_asset(storefront, "logo"),
      storefront_header_asset: storefront_asset(storefront, "header"),
      storefront_pages: storefront.pages || [],
      theme_presets: ThemePresets.all(),
      show_all_themes?: false,
      stats: dashboard_stats(products, exports, imports),
      current_params: params,
      current_url: uri
    )
  end

  defp refresh_workspace(socket, overrides \\ %{}) do
    params = Map.merge(socket.assigns.current_params || %{}, overrides)
    assign_workspace(socket, params, socket.assigns.current_url)
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

  defp page_title(:dashboard), do: ResellerWeb.PageTitle.build("Dashboard", "Workspace")
  defp page_title(:exports), do: ResellerWeb.PageTitle.build("Exports", "Workspace / Transfers")
  defp page_title(:settings), do: ResellerWeb.PageTitle.build("Settings", "Workspace")
  defp page_title(_section), do: ResellerWeb.PageTitle.build("Workspace", nil)

  defp section_eyebrow(:dashboard), do: "Dashboard"
  defp section_eyebrow(:exports), do: "Transfers"
  defp section_eyebrow(:settings), do: "Settings"
  defp section_eyebrow(_section), do: "Workspace"

  defp section_heading(:dashboard), do: "Your Resellerio workspace is now operational."
  defp section_heading(:exports), do: "Run archive exports and imports from the web."
  defp section_heading(:settings), do: "Manage your workspace defaults."
  defp section_heading(_section), do: "Your Resellerio workspace is ready."

  defp section_description(:dashboard) do
    "The dashboard now links straight into the web workflows for product intake and archive generation."
  end

  defp section_description(:exports) do
    "Exports and imports are no longer API-only. Request archive jobs and upload ZIP imports directly from this web screen."
  end

  defp section_description(:settings) do
    "Settings is now a real workspace stop and will grow into account, passkey, and default-behavior controls."
  end

  defp section_description(_section) do
    "Protected browser session is active and the Resellerio workspace now covers core operational flows."
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

  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")

  defp export_download_url(%{storage_key: nil}), do: nil

  defp export_download_url(export) do
    case Exports.download_url(export) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  defp export_filter_details(export) do
    case Exports.filter_details(export.filter_params || %{}) do
      [] -> [%{label: "Filters", value: "All products"}]
      details -> details
    end
  end

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "File type is not accepted"
  defp error_to_string(other), do: inspect(other)

  defp format_reason({:missing_config, config_key}) do
    "missing configuration: #{humanize_config_key(config_key)}. Add it to your .env or shell and restart Phoenix."
  end

  defp format_reason(%Changeset{} = changeset), do: inspect(changeset.errors)
  defp format_reason(reason), do: inspect(reason)

  defp humanize_config_key(:access_key_id), do: "TIGRIS_ACCESS_KEY_ID"
  defp humanize_config_key(:secret_access_key), do: "TIGRIS_SECRET_ACCESS_KEY"
  defp humanize_config_key(:base_url), do: "TIGRIS_BUCKET_URL"
  defp humanize_config_key(:bucket_name), do: "TIGRIS_BUCKET_NAME"
  defp humanize_config_key(config_key), do: inspect(config_key)

  defp build_marketplace_form(current_user, selected_marketplaces) do
    current_user
    |> Accounts.change_user_marketplace_settings(%{
      "selected_marketplaces" => selected_marketplaces
    })
    |> to_form(as: :settings)
  end

  defp build_storefront_form(storefront) do
    storefront
    |> Storefronts.change_storefront(%{
      "slug" => storefront.slug,
      "title" => storefront.title,
      "tagline" => storefront.tagline,
      "description" => storefront.description,
      "theme_id" => storefront.theme_id || ThemePresets.default_id(),
      "enabled" => storefront.enabled
    })
    |> to_form(as: :storefront)
  end

  defp maybe_strip_derived_slug_and_label(%StorefrontPage{id: nil}, page_params, socket) do
    page_params
    |> then(fn p ->
      if socket.assigns.storefront_page_slug_locked,
        do: p,
        else: Map.delete(p, "slug")
    end)
    |> then(fn p ->
      if socket.assigns.storefront_page_label_locked,
        do: p,
        else: Map.delete(p, "menu_label")
    end)
  end

  defp maybe_strip_derived_slug_and_label(_page, page_params, _socket), do: page_params

  defp build_storefront_page_form(page) do
    page
    |> Storefronts.change_storefront_page(%{
      "title" => page.title,
      "slug" => page.slug,
      "menu_label" => page.menu_label,
      "body" => page.body,
      "published" => page.published
    })
    |> to_form(as: :storefront_page)
  end

  defp reset_storefront_page_modal(socket) do
    assign(socket,
      show_storefront_page_modal?: false,
      editing_storefront_page: nil,
      storefront_page_slug_locked: false,
      storefront_page_label_locked: false,
      storefront_page_form: build_storefront_page_form(%StorefrontPage{})
    )
  end

  defp ensure_selected_marketplaces_param(params) do
    cond do
      Map.has_key?(params, "selected_marketplaces") ->
        params

      Map.has_key?(params, :selected_marketplaces) ->
        params

      true ->
        Map.put(params, "selected_marketplaces", [])
    end
  end

  defp consume_storefront_asset_entry(socket, entry, kind) do
    result =
      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        case File.read(path) do
          {:ok, body} ->
            checksum = Base.encode16(:crypto.hash(:sha256, body), case: :lower)

            case Storefronts.upload_storefront_asset_for_user(
                   socket.assigns.current_user,
                   kind,
                   %{
                     "filename" => entry.client_name,
                     "content_type" => entry.client_type,
                     "byte_size" => byte_size(body),
                     "checksum" => checksum
                   },
                   body
                 ) do
              {:ok, asset} -> {:ok, {:ok, asset}}
              {:error, reason} -> {:ok, {:error, reason}}
            end

          {:error, reason} ->
            {:ok, {:error, reason}}
        end
      end)

    case result do
      {:ok, _asset} ->
        socket
        |> refresh_workspace()
        |> put_flash(:info, "#{storefront_asset_label(kind)} uploaded.")

      {:error, :storefront_not_found} ->
        put_flash(socket, :error, "Save storefront details before uploading branding assets.")

      {:error, reason} ->
        put_flash(
          socket,
          :error,
          "Could not upload #{storefront_asset_label(kind)}: #{format_reason(reason)}"
        )
    end
  end

  defp upload_storefront_asset(socket, upload_name, kind) do
    storefront = socket.assigns.storefront

    cond do
      storefront.id == nil ->
        put_flash(socket, :error, "Save storefront details before uploading branding assets.")

      socket.assigns.uploads[upload_name].entries == [] ->
        put_flash(
          socket,
          :error,
          "Choose an image before uploading the #{storefront_asset_label(kind)}."
        )

      true ->
        case consume_uploaded_entries(socket, upload_name, fn %{path: path}, entry ->
               case File.read(path) do
                 {:ok, body} ->
                   checksum = Base.encode16(:crypto.hash(:sha256, body), case: :lower)

                   case Storefronts.upload_storefront_asset_for_user(
                          socket.assigns.current_user,
                          kind,
                          %{
                            "filename" => entry.client_name,
                            "content_type" => entry.client_type,
                            "byte_size" => byte_size(body),
                            "checksum" => checksum
                          },
                          body
                        ) do
                     {:ok, asset} -> {:ok, {:ok, asset}}
                     {:error, reason} -> {:ok, {:error, reason}}
                   end

                 {:error, reason} ->
                   {:ok, {:error, reason}}
               end
             end) do
          [{:ok, _asset}] ->
            socket
            |> refresh_workspace()
            |> put_flash(:info, "#{storefront_asset_label(kind)} uploaded.")

          [{:error, :storefront_not_found}] ->
            put_flash(socket, :error, "Save storefront details before uploading branding assets.")

          [{:error, reason}] ->
            put_flash(
              socket,
              :error,
              "Could not upload #{storefront_asset_label(kind)}: #{format_reason(reason)}"
            )

          _other ->
            put_flash(socket, :error, "Could not upload #{storefront_asset_label(kind)}.")
        end
    end
  end

  defp storefront_asset(storefront, kind) do
    Enum.find(storefront.assets || [], &(&1.kind == kind))
  end

  defp storefront_asset_label("logo"), do: "Logo"
  defp storefront_asset_label("header"), do: "Header image"
  defp storefront_asset_label(_kind), do: "Asset"

  defp storefront_asset_url(nil), do: nil

  defp storefront_asset_url(asset) do
    case Reseller.Media.public_url_for_storage_key(asset.storage_key) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  defp storefront_root_url(nil), do: "Save a slug to reserve the public path."
  defp storefront_root_url(""), do: "Save a slug to reserve the public path."

  defp storefront_root_url(slug) do
    ResellerWeb.Endpoint.url() <> "/store/" <> slug
  end

  defp storefront_page_url(storefront, page) do
    storefront_root_url(storefront.slug) <> "/pages/" <> page.slug
  end

  defp storefront_page_modal_title(nil), do: "Add storefront page"
  defp storefront_page_modal_title(_page), do: "Edit storefront page"

  defp storefront_page_modal_description(nil) do
    "Plain-text pages cover shipping, returns, contact, or brand story content."
  end

  defp storefront_page_modal_description(_page) do
    "Update the public copy, menu label, or published state for this page."
  end

  defp visible_theme_presets(presets, true, _current_theme_id), do: presets

  defp visible_theme_presets(presets, false, current_theme_id) do
    selected = Enum.find(presets, &(&1.id == current_theme_id))
    defaults = Enum.take(presets, 4)

    if selected && selected not in defaults do
      defaults |> List.delete_at(-1) |> List.insert_at(-1, selected)
    else
      defaults
    end
  end

  defp current_theme_id(form) do
    form[:theme_id].value || ThemePresets.default_id()
  end

  defp theme_preset_card_classes(true) do
    "rounded-[1.6rem] border border-primary bg-primary/8 px-4 py-4 shadow-[0_18px_45px_rgba(216,123,56,0.18)]"
  end

  defp theme_preset_card_classes(false) do
    "rounded-[1.6rem] border border-base-300 bg-base-50 px-4 py-4 transition hover:border-base-400"
  end

  defp theme_preset_card_style(preset) do
    colors = preset.colors

    "background: #{colors.page_background}; color: #{colors.text}; border-color: #{colors.border};"
  end

  defp theme_preview_hero_style(preset) do
    colors = preset.colors

    "background: linear-gradient(135deg, #{colors.secondary_accent}, #{colors.hero_overlay}); color: #{colors.text};"
  end

  defp theme_preview_swatches(preset) do
    colors = preset.colors
    [colors.primary_button, colors.secondary_accent, colors.page_background, colors.text]
  end

  defp truthy_field?(value), do: value in [true, "true", 1, "1", "on"]

  defp truncate_copy(nil, _limit), do: ""

  defp truncate_copy(value, limit) when is_binary(value) do
    if String.length(value) > limit do
      String.slice(value, 0, limit) <> "..."
    else
      value
    end
  end
end
