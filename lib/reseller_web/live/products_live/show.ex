defmodule ResellerWeb.ProductsLive.Show do
  use ResellerWeb, :live_view

  alias Ecto.Changeset
  alias Reseller.Catalog
  alias Reseller.Catalog.Product
  alias ResellerWeb.ProductsLive.Helpers
  alias ResellerWeb.WorkspaceNavigation

  @refresh_interval_ms 1_500

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
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
         |> assign_product(updated_product, rebuild_form: true)
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
              This page refreshes every #{@refresh_interval_ms}ms while title, brand, price research, and listing drafts arrive.
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
                  <.input field={@review_form[:title]} label="Title" />
                  <.input field={@review_form[:brand]} label="Brand" />
                  <.input field={@review_form[:category]} label="Category" />
                  <.input field={@review_form[:condition]} label="Condition" />
                  <.input field={@review_form[:color]} label="Color" />
                  <.input field={@review_form[:size]} label="Size" />
                  <.input field={@review_form[:material]} label="Material" />
                  <.input field={@review_form[:sku]} label="SKU" />
                  <.input
                    field={@review_form[:tags]}
                    label="Tags"
                    placeholder="denim, vintage, outerwear"
                    value={Helpers.tag_input_value(@review_form[:tags].value)}
                  />
                  <.input
                    field={@review_form[:price]}
                    type="number"
                    step="0.01"
                    label="Price"
                  />
                  <.input
                    field={@review_form[:cost]}
                    type="number"
                    step="0.01"
                    label="Cost"
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

            <.surface
              :if={@product.images != []}
              id="product-review-images"
              tag="article"
            >
              <.header>
                Images
                <:subtitle>
                  Original uploads and any generated variants stay attached as separate product images.
                </:subtitle>
              </.header>

              <div class="grid gap-3 sm:grid-cols-2">
                <div
                  :for={image <- @product.images}
                  class="overflow-hidden rounded-3xl border border-base-300 bg-base-50"
                >
                  <img
                    :if={image_url = Helpers.public_image_url(image)}
                    src={image_url}
                    alt={image.original_filename || image.kind}
                    class="aspect-square w-full object-cover"
                  />
                  <div class="p-3 text-sm">
                    <p class="font-semibold">{Helpers.humanize_kind(image.kind)}</p>
                    <p class="mt-1 text-xs uppercase tracking-[0.18em] text-base-content/50">
                      {image.processing_status}
                    </p>
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
                  class="rounded-2xl border border-base-300 bg-base-100 px-4 py-4"
                >
                  <p class="text-sm font-semibold">
                    {String.upcase(listing.marketplace)} · {listing.generated_title}
                  </p>
                  <p class="mt-2 text-sm leading-6 text-base-content/75">
                    {listing.generated_description}
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
          if(rebuild_form?, do: build_review_form(product), else: socket.assigns.review_form),
        review_form_dirty?: if(rebuild_form?, do: false, else: socket.assigns.review_form_dirty?)
      )

    if product.status in ["uploading", "processing"] and connected?(socket) do
      Process.send_after(self(), :refresh_product, @refresh_interval_ms)
    end

    socket
  end

  defp build_review_form(%Product{} = product) do
    product
    |> build_review_changeset(review_seed_attrs(product))
    |> to_form(as: :product)
  end

  defp build_review_changeset(%Product{} = product, attrs) do
    Product.update_changeset(product, attrs)
  end

  defp review_seed_attrs(%Product{} = product) do
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
      "tags" => product.tags,
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

  defp pipeline_state_label(:completed), do: "Done"
  defp pipeline_state_label(:active), do: "In progress"
  defp pipeline_state_label(:warning), do: "Warning"
  defp pipeline_state_label(:failed), do: "Failed"
  defp pipeline_state_label(:pending), do: "Pending"

  defp pipeline_overall_badge_classes(state) do
    [
      "badge mt-3 rounded-full border px-3 py-3 text-xs font-semibold uppercase tracking-[0.18em]",
      case state do
        :completed -> "border-success/25 bg-success/15 text-success"
        :active -> "border-info/25 bg-info/15 text-info"
        :warning -> "border-warning/25 bg-warning/20 text-warning"
        :failed -> "border-error/25 bg-error/15 text-error"
        _other -> "border-base-300 bg-base-200 text-base-content/60"
      end
    ]
  end

  defp pipeline_progress_bar_classes(state) do
    [
      "h-full rounded-full transition-all duration-500",
      case state do
        :completed -> "bg-success"
        :active -> "bg-info"
        :warning -> "bg-warning"
        :failed -> "bg-error"
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
        _other -> "border-base-300 bg-base-200 text-base-content/55"
      end
    ]
  end
end
