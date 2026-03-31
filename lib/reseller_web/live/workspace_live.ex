defmodule ResellerWeb.WorkspaceLive do
  use ResellerWeb, :live_view

  alias Ecto.Changeset
  alias Reseller.Accounts
  alias Reseller.Catalog
  alias Reseller.Exports
  alias Reseller.Imports
  alias Reseller.Marketplaces
  alias ResellerWeb.WorkspaceNavigation

  @zip_upload_accept ~w(.zip)

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
            <section id="workspace-settings" class="grid gap-4 lg:grid-cols-[1fr_1fr]">
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
    exports = Exports.list_exports_for_user(current_user)
    imports = Imports.list_imports_for_user(current_user)
    selected_marketplaces = Accounts.selected_marketplaces(current_user)

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
end
