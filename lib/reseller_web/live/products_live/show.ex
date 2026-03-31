defmodule ResellerWeb.ProductsLive.Show do
  use ResellerWeb, :live_view

  alias Ecto.Changeset
  alias Reseller.Catalog
  alias Reseller.Catalog.Product
  alias Reseller.Marketplaces
  alias Reseller.Media.Storage
  alias ResellerWeb.ProductsLive.Helpers
  alias ResellerWeb.WorkspaceNavigation

  @refresh_interval_ms 1_500
  @image_upload_accept ~w(.jpg .jpeg .png .webp)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:product_images,
       accept: @image_upload_accept,
       max_entries: 5,
       max_file_size: 25_000_000
     )
     |> assign(
       page_title: ResellerWeb.PageTitle.build("Product Review", "Workspace / Inventory"),
       workspace_nav: WorkspaceNavigation.items(:products),
       refresh_interval_ms: @refresh_interval_ms,
       manual_product_status_options: Helpers.manual_product_status_options(),
       pipeline_progress: nil,
       product: nil,
       product_id: nil,
       review_form: to_form(%{}, as: :product),
       review_form_dirty?: false
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Catalog.get_product_for_user(socket.assigns.current_user, parse_integer(id)) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Product not found.")
         |> push_navigate(to: ~p"/app/products")}

      product ->
        {:noreply, assign_product(socket, product)}
    end
  end

  @impl true
  def handle_info(:refresh_product, %{assigns: %{product_id: nil}} = socket),
    do: {:noreply, socket}

  def handle_info(:refresh_product, socket) do
    case Catalog.get_product_for_user(socket.assigns.current_user, socket.assigns.product_id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Product not found.")
         |> push_navigate(to: ~p"/app/products")}

      product ->
        {:noreply, assign_product(socket, product)}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate_product", %{"product" => product_params}, socket) do
    form =
      socket.assigns.product
      |> build_review_changeset(product_params)
      |> Map.put(:action, :validate)
      |> to_form(as: :product)

    {:noreply, assign(socket, review_form: form, review_form_dirty?: true)}
  end

  def handle_event("save_product", %{"product" => product_params}, socket) do
    case Catalog.update_product_for_user(
           socket.assigns.current_user,
           socket.assigns.product.id,
           product_params
         ) do
      {:ok, updated_product} ->
        {:noreply,
         socket
         |> assign_product(updated_product, rebuild_form: true, use_suggested_tags?: false)
         |> put_flash(:info, "Product details updated.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply,
         assign(
           socket,
           review_form: to_form(%{changeset | action: :validate}, as: :product),
           review_form_dirty?: true
         )}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not update product: #{format_reason(reason)}")}
    end
  end

  def handle_event("refresh_product", _params, socket) do
    case Catalog.get_product_for_user(socket.assigns.current_user, socket.assigns.product.id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Product not found.")
         |> push_navigate(to: ~p"/app/products")}

      product ->
        {:noreply, assign_product(socket, product, rebuild_form: false)}
    end
  end

  def handle_event("sync_product_uploads", _params, socket) do
    {:noreply, clear_flash(socket, :error)}
  end

  def handle_event("cancel-product-image", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :product_images, ref)}
  end

  def handle_event("upload_product_images", _params, socket) do
    upload_entries = socket.assigns.uploads.product_images.entries

    if upload_entries == [] do
      {:noreply, put_flash(socket, :error, "Choose at least one image to upload.")}
    else
      upload_specs = build_upload_specs(upload_entries)

      case Catalog.prepare_product_uploads_for_user(
             socket.assigns.current_user,
             socket.assigns.product.id,
             upload_specs
           ) do
        {:ok, %{upload_bundle: upload_bundle}} ->
          case upload_and_finalize_product(
                 socket,
                 socket.assigns.product.id,
                 upload_bundle.images
               ) do
            {:ok, finalized_product} ->
              {:noreply,
               socket
               |> assign_product(finalized_product, rebuild_form: false)
               |> put_flash(:info, "Images uploaded. AI processing restarted.")}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Uploads failed: #{format_reason(reason)}")}
          end

        {:error, :invalid_product_state} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Images can be changed only while the product is in draft, review, or ready."
           )}

        {:error, reason} ->
          {:noreply,
           put_flash(socket, :error, "Could not prepare uploads: #{format_reason(reason)}")}
      end
    end
  end

  def handle_event("delete_product_image", %{"image-id" => image_id}, socket) do
    case parse_integer(image_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Uploaded image not found.")}

      parsed_image_id ->
        case Catalog.delete_product_image_for_user(
               socket.assigns.current_user,
               socket.assigns.product.id,
               parsed_image_id
             ) do
          {:ok, product} ->
            {:noreply,
             socket
             |> assign_product(product, rebuild_form: false)
             |> put_flash(:info, "Image deleted.")}

          {:error, :not_found} ->
            {:noreply, put_flash(socket, :error, "Uploaded image not found.")}

          {:error, :invalid_product_state} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Images can be changed only while the product is in draft, review, or ready."
             )}

          {:error, reason} ->
            {:noreply,
             put_flash(socket, :error, "Could not delete the image: #{format_reason(reason)}")}
        end
    end
  end

  def handle_event("retry_processing", _params, socket) do
    case Catalog.retry_product_processing_for_user(
           socket.assigns.current_user,
           socket.assigns.product.id
         ) do
      {:ok, %{product: product, processing_run: processing_run}} ->
        {:noreply,
         socket
         |> assign_product(product, rebuild_form: false)
         |> put_flash(:info, "AI processing restarted with run ##{processing_run.id}.")}

      {:error, :no_product_images} ->
        {:noreply, put_flash(socket, :error, "This product has no uploaded images to process.")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not restart AI processing: #{format_reason(reason)}")}
    end
  end

  def handle_event("generate_lifestyle_images", params, socket) do
    generation_opts =
      case params["scene_key"] do
        scene_key when is_binary(scene_key) and scene_key != "" -> [scene_key: scene_key]
        _other -> []
      end

    case Catalog.generate_lifestyle_images_for_user(
           socket.assigns.current_user,
           socket.assigns.product.id,
           generation_opts
         ) do
      {:ok, %{product: product, lifestyle_generation_run: lifestyle_generation_run}} ->
        if connected?(socket) do
          Process.send_after(self(), :refresh_product, 150)
        end

        message =
          case params["scene_key"] do
            scene_key when is_binary(scene_key) and scene_key != "" ->
              "Lifestyle preview regeneration started for #{Helpers.humanize_scene_key(scene_key)}."

            _other ->
              "Lifestyle preview generation started#{run_suffix(lifestyle_generation_run)}."
          end

        {:noreply,
         socket
         |> assign_product(product, rebuild_form: false)
         |> put_flash(:info, message)}

      {:error, :no_product_images} ->
        {:noreply,
         put_flash(socket, :error, "This product has no images available for previews.")}

      {:error, :invalid_product_state} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Lifestyle preview generation unlocks after image processing finishes."
         )}

      {:error, reason} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Could not start lifestyle generation: #{format_reason(reason)}"
         )}
    end
  end

  def handle_event("approve_lifestyle_image", %{"image-id" => image_id}, socket) do
    case parse_integer(image_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Generated image not found.")}

      parsed_image_id ->
        case Catalog.approve_lifestyle_image_for_user(
               socket.assigns.current_user,
               socket.assigns.product.id,
               parsed_image_id
             ) do
          {:ok, product} ->
            {:noreply,
             socket
             |> assign_product(product, rebuild_form: false)
             |> put_flash(:info, "Lifestyle preview approved for listing use.")}

          {:error, :not_found} ->
            {:noreply, put_flash(socket, :error, "Generated image not found.")}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Could not approve the lifestyle preview: #{format_reason(reason)}"
             )}
        end
    end
  end

  def handle_event("delete_lifestyle_image", %{"image-id" => image_id}, socket) do
    case parse_integer(image_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Generated image not found.")}

      parsed_image_id ->
        case Catalog.delete_lifestyle_image_for_user(
               socket.assigns.current_user,
               socket.assigns.product.id,
               parsed_image_id
             ) do
          {:ok, product} ->
            {:noreply,
             socket
             |> assign_product(product, rebuild_form: false)
             |> put_flash(:info, "Lifestyle preview deleted.")}

          {:error, :not_found} ->
            {:noreply, put_flash(socket, :error, "Generated image not found.")}

          {:error, reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Could not delete the lifestyle preview: #{format_reason(reason)}"
             )}
        end
    end
  end

  def handle_event("mark_sold", _params, socket) do
    {:noreply,
     mutate_product(
       socket,
       "Product marked as sold.",
       &Catalog.mark_product_sold_for_user/2
     )}
  end

  def handle_event("archive_product", _params, socket) do
    {:noreply, mutate_product(socket, "Product archived.", &Catalog.archive_product_for_user/2)}
  end

  def handle_event("restore_product", _params, socket) do
    {:noreply, mutate_product(socket, "Product restored.", &Catalog.unarchive_product_for_user/2)}
  end

  def handle_event("delete_product", _params, socket) do
    case Catalog.delete_product_for_user(socket.assigns.current_user, socket.assigns.product.id) do
      {:ok, _product} ->
        {:noreply,
         socket
         |> put_flash(:info, "Product deleted.")
         |> push_navigate(to: ~p"/app/products")}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Could not delete product: #{format_reason(reason)}")}
    end
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
      <section :if={@product} class="grid gap-6">
        <.section_intro
          id="product-review-heading"
          eyebrow="Inventory"
          title={@product.title || "Untitled product"}
          description="Step 2 of 2. Confirm the recognized product data, pricing research, and lifecycle fields before you list or sell the item."
        >
          <div class="mt-6 flex flex-wrap items-center gap-3">
            <span class="badge badge-outline badge-lg">Step 1 · Upload complete</span>
            <span class="badge badge-primary badge-lg">Step 2 · Review AI fields</span>
            <.status_badge status={@product.status} class="badge-lg" />
            <span :if={@product.ai_confidence} class="badge badge-outline badge-lg">
              AI {Float.round(@product.ai_confidence, 2)}
            </span>
          </div>
        </.section_intro>

        <div
          :if={@product.status in ["uploading", "processing"]}
          id="product-processing-banner"
          class="alert alert-info shadow-sm"
        >
          <.icon name="hero-arrow-path" class="size-5 motion-safe:animate-spin" />
          <div>
            <p class="font-semibold">AI processing is still running.</p>
            <p class="text-sm">
              This page refreshes every #{@refresh_interval_ms}ms while title, brand, price research, listing drafts, and real-life previews arrive.
            </p>
          </div>
          <button
            id="refresh-product-button"
            type="button"
            phx-click="refresh_product"
            class="btn btn-outline btn-sm rounded-full"
          >
            Refresh now
          </button>
        </div>

        <.surface id="product-pipeline-progress" tag="article">
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="max-w-3xl">
              <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">
                Processing pipeline
              </p>
              <p class="mt-2 text-2xl font-semibold tracking-[-0.03em]">
                {@pipeline_progress.headline}
              </p>
              <p class="mt-2 text-sm leading-6 text-base-content/70">
                {@pipeline_progress.summary}
              </p>
            </div>

            <div class="rounded-3xl border border-base-300 bg-base-50 px-5 py-4 text-right">
              <p class="text-xs uppercase tracking-[0.2em] text-base-content/45">
                Overall progress
              </p>
              <p class="mt-2 text-3xl font-semibold tracking-[-0.04em]">
                {@pipeline_progress.completed_count}/{@pipeline_progress.total_count}
              </p>
              <span class={pipeline_overall_badge_classes(@pipeline_progress.state)}>
                {pipeline_state_label(@pipeline_progress.state)}
              </span>
            </div>
          </div>

          <div class="mt-6 h-2 overflow-hidden rounded-full bg-base-200">
            <div
              id="pipeline-progressbar"
              role="progressbar"
              aria-label="Product processing progress"
              aria-valuemin="0"
              aria-valuemax="100"
              aria-valuenow={@pipeline_progress.percent}
              aria-valuetext={
                "#{@pipeline_progress.completed_count} of #{@pipeline_progress.total_count} steps complete"
              }
              class={pipeline_progress_bar_classes(@pipeline_progress.state)}
              style={"width: #{@pipeline_progress.percent}%"}
            >
            </div>
          </div>

          <ol class="mt-6 grid gap-3 lg:grid-cols-2 2xl:grid-cols-4">
            <li
              :for={step <- @pipeline_progress.steps}
              id={"pipeline-step-#{step.id}"}
              class={pipeline_step_card_classes(step.state)}
            >
              <div class="flex items-start gap-3">
                <div class={pipeline_step_icon_wrap_classes(step.state)}>
                  <.icon name={step.icon} class="size-5" />
                </div>

                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-2">
                    <p class="text-sm font-semibold tracking-[-0.02em]">{step.label}</p>
                    <span
                      id={"pipeline-step-#{step.id}-state"}
                      class={pipeline_step_state_badge_classes(step.state)}
                    >
                      {pipeline_state_label(step.state)}
                    </span>
                  </div>

                  <p class="mt-2 text-sm leading-6 text-base-content/70">{step.detail}</p>
                </div>
              </div>
            </li>
          </ol>
        </.surface>

        <section class="grid gap-4 xl:grid-cols-[1.08fr_0.92fr]">
          <div class="grid gap-4">
            <.surface id="product-review-form-card" tag="article">
              <.header>
                Review and save
                <:subtitle>
                  Fields are seeded from the latest AI recognition result and price research. Saving persists them onto the product.
                </:subtitle>
                <:actions>
                  <.link navigate={~p"/app/products"} class="btn btn-ghost btn-sm rounded-full">
                    Back to index
                  </.link>
                </:actions>
              </.header>

              <.form
                for={@review_form}
                id="product-review-form"
                phx-change="validate_product"
                phx-submit="save_product"
                class="grid gap-4"
              >
                <div class="grid gap-3 md:grid-cols-2">
                  <.input
                    field={@review_form[:status]}
                    type="select"
                    label="Status"
                    options={@manual_product_status_options}
                    disabled={status_locked?(@product)}
                  />
                  <.input field={@review_form[:title]} label="Title" copyable />
                  <.input field={@review_form[:brand]} label="Brand" copyable />
                  <.input field={@review_form[:category]} label="Category" copyable />
                  <.input field={@review_form[:condition]} label="Condition" copyable />
                  <.input field={@review_form[:color]} label="Color" copyable />
                  <.input field={@review_form[:size]} label="Size" copyable />
                  <.input field={@review_form[:material]} label="Material" copyable />
                  <.input field={@review_form[:sku]} label="SKU" copyable />
                  <.input
                    field={@review_form[:tags]}
                    label="Tags"
                    placeholder="denim, vintage, outerwear"
                    value={Helpers.tag_input_value(@review_form[:tags].value)}
                    copyable
                  />
                  <.input
                    field={@review_form[:price]}
                    type="number"
                    step="0.01"
                    label="Price"
                    copyable
                  />
                  <.input
                    field={@review_form[:cost]}
                    type="number"
                    step="0.01"
                    label="Cost"
                    copyable
                  />
                </div>

                <div class="grid gap-3 md:grid-cols-2">
                  <.surface tag="div" variant="soft" padding="md">
                    <p class="text-xs uppercase tracking-[0.22em] text-base-content/50">
                      Suggested ask
                    </p>
                    <p class="mt-2 text-2xl font-semibold">
                      {Helpers.decimal_to_string(
                        @product.price_research && @product.price_research.suggested_target_price
                      ) || "—"}
                    </p>
                    <p class="mt-2 text-sm text-base-content/70">
                      Seeded into the `price` field when you have not saved a manual price yet.
                    </p>
                  </.surface>

                  <.surface tag="div" variant="soft" padding="md">
                    <p class="text-xs uppercase tracking-[0.22em] text-base-content/50">
                      Suggested floor
                    </p>
                    <p class="mt-2 text-2xl font-semibold">
                      {Helpers.decimal_to_string(
                        @product.price_research && @product.price_research.suggested_min_price
                      ) || "—"}
                    </p>
                    <p class="mt-2 text-sm text-base-content/70">
                      Seeded into the `cost` field until you replace it with your real acquisition cost.
                    </p>
                  </.surface>
                </div>

                <.input
                  field={@review_form[:notes]}
                  type="textarea"
                  rows="4"
                  label="Notes"
                  placeholder="Fit notes, defects, or seller-only reminders"
                  copyable
                />

                <div class="flex flex-wrap gap-2">
                  <.button class="btn btn-primary rounded-full">Save product</.button>
                  <button
                    :if={Helpers.retry_processing_available?(@product)}
                    id="retry-processing-button"
                    type="button"
                    phx-click="retry_processing"
                    class="btn btn-outline btn-sm rounded-full"
                  >
                    Retry AI
                  </button>
                  <button
                    :if={@product.status != "sold"}
                    type="button"
                    phx-click="mark_sold"
                    class="btn btn-outline btn-sm rounded-full"
                  >
                    Mark sold
                  </button>
                  <button
                    :if={@product.status != "archived"}
                    type="button"
                    phx-click="archive_product"
                    class="btn btn-outline btn-sm rounded-full"
                  >
                    Archive
                  </button>
                  <button
                    :if={@product.status == "archived"}
                    type="button"
                    phx-click="restore_product"
                    class="btn btn-outline btn-sm rounded-full"
                  >
                    Restore
                  </button>
                  <button
                    type="button"
                    phx-click="delete_product"
                    data-confirm="Delete this product?"
                    class="btn btn-ghost btn-sm rounded-full text-error"
                  >
                    Delete
                  </button>
                </div>
              </.form>
            </.surface>

            <.surface id="product-review-images" tag="article">
              <.header>
                Images
                <:subtitle>
                  Each uploaded photo keeps its original plus one background-removed processing variant, and you can swap photos before the product is sold or archived.
                </:subtitle>
              </.header>

              <div>
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <p class="text-xs uppercase tracking-[0.22em] text-base-content/50">
                      Uploaded and processed images
                    </p>
                    <p class="mt-2 max-w-2xl text-sm leading-6 text-base-content/70">
                      Review each uploaded source photo alongside its cleaned background-removed version, delete outdated shots, and upload replacements without leaving this page.
                    </p>
                  </div>
                  <span class="badge rounded-full border border-base-300 bg-base-100 px-3 py-3 text-xs font-semibold uppercase tracking-[0.16em] text-base-content/60">
                    {length(Helpers.product_image_groups(@product))} uploaded
                  </span>
                </div>

                <div
                  :if={Helpers.product_image_groups(@product) == []}
                  id="product-image-gallery-empty"
                  class="mt-4 rounded-[1.75rem] border border-dashed border-base-300 bg-base-50 px-5 py-5 text-sm leading-6 text-base-content/68"
                >
                  No uploaded product photos are attached right now. Add new images below to
                  restart the review pipeline.
                </div>

                <div
                  :if={Helpers.product_image_groups(@product) != []}
                  id="product-image-gallery"
                  class="mt-4 grid gap-4 xl:grid-cols-2"
                >
                  <div
                    :for={group <- Helpers.product_image_groups(@product)}
                    id={"product-image-group-#{group.original.id}"}
                    class="overflow-hidden rounded-[1.75rem] border border-base-300 bg-base-50"
                  >
                    <div class="border-b border-base-300/80 px-4 py-4">
                      <div class="flex flex-wrap items-start justify-between gap-3">
                        <div>
                          <p class="text-xs uppercase tracking-[0.22em] text-base-content/50">
                            Upload {group.original.position}
                          </p>
                          <p class="mt-2 text-base font-semibold leading-6 text-base-content">
                            {group.original.original_filename || "Original photo"}
                          </p>
                          <p class="mt-1 text-xs uppercase tracking-[0.18em] text-base-content/50">
                            {group.original.processing_status}
                          </p>
                        </div>
                        <button
                          :if={Helpers.product_image_management_available?(@product)}
                          id={"delete-product-image-#{group.original.id}"}
                          type="button"
                          phx-click="delete_product_image"
                          phx-value-image-id={group.original.id}
                          data-confirm="Delete this uploaded image and its processed variants?"
                          class="btn btn-ghost btn-xs rounded-full text-error"
                        >
                          Delete
                        </button>
                      </div>
                    </div>

                    <div class="grid gap-3 p-4 md:grid-cols-2">
                      <div class="overflow-hidden rounded-3xl border border-base-300 bg-base-100">
                        <img
                          :if={image_url = Helpers.public_image_url(group.original)}
                          id={"product-image-original-#{group.original.id}"}
                          src={image_url}
                          alt={group.original.original_filename || group.original.kind}
                          class="aspect-square w-full object-cover"
                        />
                        <div class="p-3 text-sm">
                          <p class="font-semibold">Original</p>
                          <p class="mt-1 text-xs uppercase tracking-[0.18em] text-base-content/50">
                            {group.original.processing_status}
                          </p>
                        </div>
                      </div>

                      <div class="overflow-hidden rounded-3xl border border-base-300 bg-base-100">
                        <img
                          :if={image_url = Helpers.public_image_url(group.background_removed)}
                          id={"product-image-background-#{group.original.id}"}
                          src={image_url}
                          alt={
                            (group.background_removed &&
                               (group.background_removed.original_filename ||
                                  group.background_removed.kind)) ||
                              "Background removed image"
                          }
                          class="aspect-square w-full object-cover"
                        />
                        <div class="p-3 text-sm">
                          <p class="font-semibold">Background removed</p>
                          <p class="mt-1 text-xs uppercase tracking-[0.18em] text-base-content/50">
                            {if(group.background_removed,
                              do: group.background_removed.processing_status,
                              else: "pending"
                            )}
                          </p>
                          <p
                            :if={!group.background_removed}
                            class="mt-2 text-xs leading-5 text-base-content/65"
                          >
                            This processed variant appears after image processing finishes.
                          </p>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="mt-8 border-t border-base-300/80 pt-6">
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <p class="text-xs uppercase tracking-[0.22em] text-base-content/50">
                      Manage photos
                    </p>
                    <p class="mt-2 max-w-2xl text-sm leading-6 text-base-content/70">
                      Add fresh photos here when you want the AI to rerun on a better image set.
                    </p>
                  </div>
                  <span
                    :if={!Helpers.product_image_management_available?(@product)}
                    class="badge rounded-full border border-base-300 bg-base-100 px-3 py-3 text-xs font-semibold uppercase tracking-[0.16em] text-base-content/60"
                  >
                    Locked while {@product.status}
                  </span>
                </div>

                <.form
                  :if={Helpers.product_image_management_available?(@product)}
                  for={to_form(%{}, as: :product_images)}
                  id="product-image-upload-form"
                  phx-change="sync_product_uploads"
                  phx-submit="upload_product_images"
                  class="mt-4"
                >
                  <.upload_panel
                    id="review-product-upload-panel"
                    title="Add or replace photos"
                    description="Upload JPG, PNG, or WEBP files. New photos are attached to this product and AI processing restarts automatically."
                    upload={@uploads.product_images}
                    cancel_event="cancel-product-image"
                    errors={Enum.map(upload_errors(@uploads.product_images), &error_to_string/1)}
                  />

                  <div class="mt-5 flex flex-wrap items-center gap-3">
                    <.button class="btn btn-primary rounded-full">Upload new images</.button>
                    <p class="text-sm leading-6 text-base-content/60">
                      Delete outdated photos above first if you are replacing the whole set.
                    </p>
                  </div>
                </.form>

                <div
                  :if={!Helpers.product_image_management_available?(@product)}
                  class="mt-4 rounded-[1.5rem] border border-base-300 bg-base-50 px-4 py-4 text-sm leading-6 text-base-content/68"
                >
                  Image edits are available only while the product is in draft, review, or ready.
                </div>
              </div>

              <div class="mt-8 border-t border-base-300/80 pt-6">
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <div>
                    <p class="text-xs uppercase tracking-[0.22em] text-base-content/50">
                      Step 8 · Real-life previews
                    </p>
                    <p class="mt-2 max-w-2xl text-sm leading-6 text-base-content/70">
                      {Helpers.lifestyle_preview_headline(@product)}
                    </p>
                  </div>
                  <div class="flex flex-wrap items-center justify-end gap-2">
                    <span class="badge rounded-full border border-info/20 bg-info/10 px-3 py-3 text-xs font-semibold uppercase tracking-[0.16em] text-info">
                      {Helpers.lifestyle_preview_badge(@product)}
                    </span>
                    <span
                      :if={Helpers.approved_lifestyle_preview_count(@product) > 0}
                      class="badge rounded-full border border-success/20 bg-success/10 px-3 py-3 text-xs font-semibold uppercase tracking-[0.16em] text-success"
                    >
                      {Helpers.approved_lifestyle_preview_count(@product)} approved
                    </span>
                    <button
                      :if={Helpers.lifestyle_generation_available?(@product)}
                      id="generate-lifestyle-images-button"
                      type="button"
                      phx-click="generate_lifestyle_images"
                      class="btn btn-outline btn-sm rounded-full"
                    >
                      {if(
                        Helpers.lifestyle_preview_images(@product) == [],
                        do: "Generate previews",
                        else: "Regenerate all"
                      )}
                    </button>
                  </div>
                </div>

                <div
                  :if={Helpers.lifestyle_preview_images(@product) == []}
                  id="product-lifestyle-preview-empty"
                  class="mt-4 rounded-[1.75rem] border border-dashed border-base-300 bg-base-50 px-5 py-5 text-sm leading-6 text-base-content/68"
                >
                  This optional final step runs after image processing and uses the uploaded product
                  images to generate 2-3 AI real-life previews.
                </div>

                <div
                  :if={Helpers.lifestyle_preview_images(@product) != []}
                  id="product-lifestyle-preview-gallery"
                  class="mt-4 grid gap-3 sm:grid-cols-2"
                >
                  <div
                    :for={image <- Helpers.lifestyle_preview_images(@product)}
                    id={"lifestyle-preview-image-#{image.id}"}
                    class="overflow-hidden rounded-3xl border border-info/20 bg-info/5"
                  >
                    <img
                      :if={image_url = Helpers.public_image_url(image)}
                      src={image_url}
                      alt={image.original_filename || image.kind}
                      class="aspect-square w-full object-cover"
                    />
                    <div class="p-3 text-sm">
                      <div class="flex flex-wrap items-start justify-between gap-3">
                        <div>
                          <p class="font-semibold">AI-generated real-life preview</p>
                          <p class="mt-1 text-xs uppercase tracking-[0.18em] text-base-content/50">
                            {image.processing_status}
                          </p>
                        </div>
                        <span class={[
                          "inline-flex items-center rounded-full border px-2.5 py-1 text-[0.68rem] font-semibold uppercase tracking-[0.16em]",
                          Helpers.lifestyle_preview_status_badge_classes(image)
                        ]}>
                          {Helpers.lifestyle_preview_status_label(image)}
                        </span>
                      </div>
                      <p class="mt-2 text-xs leading-5 text-base-content/70">
                        Uses uploaded product images
                        <span :if={image.scene_key}>
                          · {Helpers.humanize_scene_key(image.scene_key)}
                        </span>
                      </p>
                      <p :if={image.approved_at} class="mt-2 text-xs leading-5 text-base-content/60">
                        Approved {Helpers.format_datetime(image.approved_at)}
                      </p>
                      <div class="mt-3 flex flex-wrap gap-2">
                        <button
                          :if={!image.seller_approved}
                          id={"approve-lifestyle-image-#{image.id}"}
                          type="button"
                          phx-click="approve_lifestyle_image"
                          phx-value-image-id={image.id}
                          class="btn btn-primary btn-xs rounded-full"
                        >
                          Approve
                        </button>
                        <button
                          id={"regenerate-lifestyle-scene-#{image.id}"}
                          type="button"
                          phx-click="generate_lifestyle_images"
                          phx-value-scene_key={image.scene_key}
                          class="btn btn-outline btn-xs rounded-full"
                        >
                          Regenerate scene
                        </button>
                        <button
                          id={"delete-lifestyle-image-#{image.id}"}
                          type="button"
                          phx-click="delete_lifestyle_image"
                          phx-value-image-id={image.id}
                          data-confirm="Delete this lifestyle preview?"
                          class="btn btn-ghost btn-xs rounded-full text-error"
                        >
                          Delete
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </.surface>
          </div>

          <div class="grid gap-4">
            <.surface tag="article" variant="soft">
              <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">AI summary</p>
              <p class="mt-3 text-sm leading-6 text-base-content/75">
                {@product.ai_summary || "No AI summary has been generated yet."}
              </p>
            </.surface>

            <.surface
              :if={@product.description_draft}
              tag="article"
              variant="soft"
            >
              <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">
                Description draft
              </p>
              <p class="mt-3 text-lg font-semibold">
                {@product.description_draft.suggested_title}
              </p>
              <p class="mt-2 text-sm leading-6 text-base-content/75">
                {@product.description_draft.short_description}
              </p>
            </.surface>

            <.surface
              :if={@product.price_research}
              id="product-price-research"
              tag="article"
              variant="soft"
            >
              <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">Price research</p>
              <div class="mt-4 grid gap-3 sm:grid-cols-3">
                <div class="rounded-2xl border border-base-300 bg-base-100 px-3 py-3">
                  <p class="text-xs uppercase tracking-[0.16em] text-base-content/45">Min</p>
                  <p class="mt-2 text-lg font-semibold">
                    {Helpers.decimal_to_string(@product.price_research.suggested_min_price) || "—"}
                  </p>
                </div>
                <div class="rounded-2xl border border-base-300 bg-base-100 px-3 py-3">
                  <p class="text-xs uppercase tracking-[0.16em] text-base-content/45">Target</p>
                  <p class="mt-2 text-lg font-semibold">
                    {Helpers.decimal_to_string(@product.price_research.suggested_target_price) || "—"}
                  </p>
                </div>
                <div class="rounded-2xl border border-base-300 bg-base-100 px-3 py-3">
                  <p class="text-xs uppercase tracking-[0.16em] text-base-content/45">Median</p>
                  <p class="mt-2 text-lg font-semibold">
                    {Helpers.decimal_to_string(@product.price_research.suggested_median_price) || "—"}
                  </p>
                </div>
              </div>
              <p class="mt-4 text-sm leading-6 text-base-content/75">
                {@product.price_research.rationale_summary}
              </p>
            </.surface>

            <.surface
              :if={@product.marketplace_listings != []}
              tag="article"
              variant="soft"
            >
              <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">
                Marketplace listings
              </p>
              <div class="mt-4 space-y-3">
                <div
                  :for={listing <- @product.marketplace_listings}
                  class="rounded-[1.75rem] border border-base-300 bg-base-100 px-4 py-4 shadow-[0_18px_45px_rgba(15,23,42,0.06)]"
                >
                  <div class="flex flex-wrap items-start justify-between gap-3">
                    <div class="min-w-0">
                      <p class="text-[11px] uppercase tracking-[0.26em] text-base-content/45">
                        Marketplace
                      </p>
                      <p class="mt-2 text-lg font-semibold tracking-[-0.02em] text-base-content">
                        {Marketplaces.marketplace_label(listing.marketplace)}
                      </p>
                    </div>

                    <div class="flex flex-wrap gap-2">
                      <button
                        id={"copy-marketplace-title-#{listing.id}"}
                        type="button"
                        phx-hook="ClipboardButton"
                        data-copy-text={listing.generated_title || ""}
                        data-copy-default-label="Copy title"
                        data-copy-success-label="Title copied"
                        class="btn btn-ghost btn-xs rounded-full border border-base-300 bg-base-50/90 px-3 normal-case text-base-content/70 hover:border-base-400 hover:bg-base-100"
                      >
                        <.icon name="hero-document-duplicate" class="size-3.5" />
                        <span data-copy-label>Copy title</span>
                      </button>

                      <button
                        id={"copy-marketplace-description-#{listing.id}"}
                        type="button"
                        phx-hook="ClipboardButton"
                        data-copy-text={Helpers.listing_description_copy_text(listing)}
                        data-copy-default-label="Copy description"
                        data-copy-success-label="Description copied"
                        class="btn btn-ghost btn-xs rounded-full border border-base-300 bg-base-50/90 px-3 normal-case text-base-content/70 hover:border-base-400 hover:bg-base-100"
                      >
                        <.icon name="hero-document-text" class="size-3.5" />
                        <span data-copy-label>Copy description</span>
                      </button>
                    </div>
                  </div>

                  <div class="mt-4 space-y-3">
                    <div class="rounded-2xl border border-base-300/80 bg-base-50 px-4 py-3">
                      <p class="text-[11px] uppercase tracking-[0.22em] text-base-content/45">
                        Title
                      </p>
                      <p
                        id={"marketplace-title-#{listing.id}"}
                        class="mt-2 text-sm font-semibold leading-6 text-base-content"
                      >
                        {listing.generated_title}
                      </p>
                    </div>

                    <div class="rounded-2xl border border-base-300/80 bg-base-50 px-4 py-3">
                      <p class="text-[11px] uppercase tracking-[0.22em] text-base-content/45">
                        Description
                      </p>
                      <p
                        id={"marketplace-description-#{listing.id}"}
                        class="mt-2 whitespace-pre-line text-sm leading-6 text-base-content/75"
                      >
                        {Helpers.listing_description_text(listing)}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </.surface>

            <.surface
              :if={@product.lifestyle_generation_runs != []}
              id="product-lifestyle-generation-runs"
              tag="article"
              variant="soft"
            >
              <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">
                Lifestyle image runs
              </p>
              <div class="mt-4 space-y-3 text-sm">
                <div
                  :for={run <- Enum.take(@product.lifestyle_generation_runs, 5)}
                  class="rounded-2xl border border-base-300 bg-base-100 px-4 py-4"
                >
                  <div class="flex flex-wrap items-center justify-between gap-3">
                    <p class="font-semibold">{run.status} · {run.step}</p>
                    <p class="text-xs uppercase tracking-[0.16em] text-base-content/45">
                      {Helpers.format_datetime(run.inserted_at)}
                    </p>
                  </div>
                  <p class="mt-2 leading-6 text-base-content/70">
                    {Helpers.lifestyle_generation_run_detail(run)}
                  </p>
                </div>
              </div>
            </.surface>

            <.surface
              :if={@product.processing_runs != []}
              id="product-processing-runs"
              tag="article"
              variant="soft"
            >
              <p class="text-xs uppercase tracking-[0.24em] text-base-content/50">
                Processing runs
              </p>
              <div class="mt-4 space-y-3 text-sm">
                <div
                  :for={run <- Enum.take(@product.processing_runs, 5)}
                  class="rounded-2xl border border-base-300 bg-base-100 px-4 py-4"
                >
                  <div class="flex flex-wrap items-center justify-between gap-3">
                    <p class="font-semibold">{run.status} · {run.step}</p>
                    <p class="text-xs uppercase tracking-[0.16em] text-base-content/45">
                      {Helpers.format_datetime(run.inserted_at)}
                    </p>
                  </div>
                  <p
                    :if={Helpers.processing_run_detail(run)}
                    class="mt-2 leading-6 text-base-content/70"
                  >
                    {Helpers.processing_run_detail(run)}
                  </p>
                </div>
              </div>
            </.surface>
          </div>
        </section>
      </section>
    </Layouts.app_shell>
    """
  end

  defp assign_product(socket, product, opts \\ [])
  defp assign_product(socket, nil, _opts), do: socket

  defp assign_product(socket, %Product{} = product, opts) do
    rebuild_form? = Keyword.get(opts, :rebuild_form, !socket.assigns.review_form_dirty?)
    use_suggested_tags? = Keyword.get(opts, :use_suggested_tags?, true)

    socket =
      assign(socket,
        page_title:
          ResellerWeb.PageTitle.build(
            product.title || "Product Review",
            "Workspace / Inventory"
          ),
        pipeline_progress: Helpers.pipeline_progress(product),
        product: product,
        product_id: product.id,
        review_form:
          if(rebuild_form?,
            do: build_review_form(product, use_suggested_tags?: use_suggested_tags?),
            else: socket.assigns.review_form
          ),
        review_form_dirty?: if(rebuild_form?, do: false, else: socket.assigns.review_form_dirty?)
      )

    if refresh_needed?(product) and connected?(socket) do
      Process.send_after(self(), :refresh_product, @refresh_interval_ms)
    end

    socket
  end

  defp build_review_form(%Product{} = product, opts) do
    product
    |> build_review_changeset(review_seed_attrs(product, opts))
    |> to_form(as: :product)
  end

  defp build_review_changeset(%Product{} = product, attrs) do
    Product.update_changeset(product, attrs)
  end

  defp review_seed_attrs(%Product{} = product, opts) do
    seed_tags? = Keyword.get(opts, :use_suggested_tags?, true)

    %{
      "status" => review_status(product),
      "title" => product.title,
      "brand" => product.brand,
      "category" => product.category,
      "condition" => product.condition,
      "color" => product.color,
      "size" => product.size,
      "material" => product.material,
      "price" => Helpers.suggested_price(product),
      "cost" => Helpers.suggested_cost(product),
      "sku" => product.sku,
      "tags" =>
        if(seed_tags? and List.wrap(product.tags) == [],
          do: Helpers.suggested_product_tags(product),
          else: product.tags
        ),
      "notes" => product.notes
    }
  end

  defp review_status(%Product{status: status})
       when status in ["draft", "review", "ready", "sold", "archived"],
       do: status

  defp review_status(_product), do: "review"

  defp status_locked?(%Product{status: status}), do: status in ["uploading", "processing"]
  defp status_locked?(_product), do: false

  defp mutate_product(socket, success_message, action_fun) do
    case action_fun.(socket.assigns.current_user, socket.assigns.product.id) do
      {:ok, product} ->
        socket
        |> assign_product(product, rebuild_form: true)
        |> put_flash(:info, success_message)

      {:error, reason} ->
        put_flash(socket, :error, "Could not update product: #{format_reason(reason)}")
    end
  end

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp parse_integer(_value), do: nil

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

  defp upload_and_finalize_product(socket, product_id, images) do
    case upload_product_entries(socket, images) do
      {:ok, []} ->
        {:ok, socket.assigns.product}

      {:ok, uploaded_entries} ->
        case Catalog.finalize_product_uploads_for_user(
               socket.assigns.current_user,
               product_id,
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

  defp checksum(binary), do: Base.encode16(:crypto.hash(:sha256, binary), case: :lower)

  defp run_suffix(nil), do: ""
  defp run_suffix(run), do: " with run ##{run.id}"

  defp format_reason({:missing_config, config_key}) do
    "missing configuration: #{humanize_config_key(config_key)}. Add it to your .env or shell and restart Phoenix."
  end

  defp format_reason(%Changeset{} = changeset), do: inspect(changeset.errors)
  defp format_reason(reason), do: inspect(reason)

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "File type is not accepted"
  defp error_to_string(other), do: inspect(other)

  defp humanize_config_key(:access_key_id), do: "TIGRIS_ACCESS_KEY_ID"
  defp humanize_config_key(:secret_access_key), do: "TIGRIS_SECRET_ACCESS_KEY"
  defp humanize_config_key(:base_url), do: "TIGRIS_BUCKET_URL"
  defp humanize_config_key(:bucket_name), do: "TIGRIS_BUCKET_NAME"
  defp humanize_config_key(config_key), do: inspect(config_key)

  defp refresh_needed?(%Product{} = product) do
    product.status in ["uploading", "processing"] or
      Helpers.lifestyle_generation_inflight?(product)
  end

  defp pipeline_state_label(:completed), do: "Done"
  defp pipeline_state_label(:active), do: "In progress"
  defp pipeline_state_label(:warning), do: "Warning"
  defp pipeline_state_label(:failed), do: "Failed"
  defp pipeline_state_label(:optional), do: "Optional"
  defp pipeline_state_label(:pending), do: "Pending"

  defp pipeline_overall_badge_classes(state) do
    [
      "badge mt-3 rounded-full border px-3 py-3 text-xs font-semibold uppercase tracking-[0.18em]",
      case state do
        :completed -> "border-success/25 bg-success/15 text-success"
        :active -> "border-info/25 bg-info/15 text-info"
        :warning -> "border-warning/25 bg-warning/20 text-warning"
        :failed -> "border-error/25 bg-error/15 text-error"
        :optional -> "border-base-300 bg-base-100 text-base-content/60"
        _other -> "border-base-300 bg-base-200 text-base-content/60"
      end
    ]
  end

  defp pipeline_progress_bar_classes(state) do
    [
      "h-full rounded-full transition-all duration-500",
      case state do
        :completed -> "bg-success"
        :active -> "bg-info reseller-progress-bar-active"
        :warning -> "bg-warning"
        :failed -> "bg-error"
        :optional -> "bg-base-300"
        _other -> "bg-base-300"
      end
    ]
  end

  defp pipeline_step_card_classes(state) do
    [
      "rounded-[1.5rem] border px-4 py-4 transition",
      case state do
        :completed -> "border-success/20 bg-success/10"
        :active -> "border-info/30 bg-info/10 shadow-[0_18px_50px_rgba(30,136,229,0.12)]"
        :warning -> "border-warning/30 bg-warning/10"
        :failed -> "border-error/30 bg-error/10"
        :optional -> "border-base-300 bg-base-100/80"
        _other -> "border-base-300 bg-base-50"
      end
    ]
  end

  defp pipeline_step_icon_wrap_classes(state) do
    [
      "mt-0.5 flex size-10 shrink-0 items-center justify-center rounded-2xl border",
      case state do
        :completed -> "border-success/20 bg-success text-success-content"
        :active -> "border-info/25 bg-info text-info-content"
        :warning -> "border-warning/25 bg-warning text-warning-content"
        :failed -> "border-error/25 bg-error text-error-content"
        :optional -> "border-base-300 bg-base-100 text-base-content/60"
        _other -> "border-base-300 bg-base-100 text-base-content/55"
      end
    ]
  end

  defp pipeline_step_state_badge_classes(state) do
    [
      "inline-flex items-center rounded-full border px-2.5 py-1 text-[0.68rem] font-semibold uppercase tracking-[0.16em]",
      case state do
        :completed -> "border-success/20 bg-success/15 text-success"
        :active -> "border-info/20 bg-info/15 text-info"
        :warning -> "border-warning/20 bg-warning/20 text-warning"
        :failed -> "border-error/20 bg-error/15 text-error"
        :optional -> "border-base-300 bg-base-100 text-base-content/60"
        _other -> "border-base-300 bg-base-200 text-base-content/55"
      end
    ]
  end
end
