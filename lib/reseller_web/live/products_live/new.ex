defmodule ResellerWeb.ProductsLive.New do
  use ResellerWeb, :live_view

  alias Ecto.Changeset
  alias Reseller.Catalog
  alias Reseller.Media.Storage
  alias ResellerWeb.ProductsLive.Helpers
  alias ResellerWeb.WorkspaceNavigation

  @image_upload_accept ~w(.jpg .jpeg .png .webp)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:product_images,
       accept: @image_upload_accept,
       max_entries: 10,
       max_file_size: 25_000_000
     )
     |> assign(
       page_title: ResellerWeb.PageTitle.build("New Product", "Workspace / Intake"),
       workspace_nav: WorkspaceNavigation.items(:products),
       product_tabs: Catalog.list_product_tabs_for_user(socket.assigns.current_user),
       new_product_form: to_form(%{"product_tab_id" => nil}, as: :product)
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    product_tab_id =
      case Map.get(params, "tab") do
        value when is_binary(value) ->
          if Catalog.get_product_tab_for_user(socket.assigns.current_user, value) do
            value
          else
            nil
          end

        _other ->
          nil
      end

    {:noreply,
     assign(socket,
       new_product_form: to_form(%{"product_tab_id" => product_tab_id}, as: :product)
     )}
  end

  @impl true
  def handle_event("create_product", %{"product" => product_params}, socket) do
    upload_entries = socket.assigns.uploads.product_images.entries

    if upload_entries == [] do
      {:noreply, put_flash(socket, :error, "Choose at least one image to start a new product.")}
    else
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
               |> put_flash(
                 :info,
                 "Images uploaded. Review the AI suggestions on the product page."
               )
               |> push_navigate(to: ~p"/app/products/#{finalized_product.id}")}

            {:error, reason} ->
              {:noreply, put_flash(socket, :error, "Uploads failed: #{format_reason(reason)}")}
          end

        {:error, %Changeset{} = changeset} ->
          {:noreply,
           socket
           |> assign(new_product_form: to_form(%{changeset | action: :validate}, as: :product))
           |> put_flash(:error, "Product is invalid: #{inspect(changeset.errors)}")}

        {:error, reason} ->
          {:noreply,
           put_flash(socket, :error, "Could not create product: #{format_reason(reason)}")}
      end
    end
  end

  def handle_event("sync_product_uploads", %{"product" => product_params}, socket) do
    {:noreply,
     socket
     |> assign(new_product_form: to_form(product_params, as: :product))
     |> clear_flash(:error)}
  end

  def handle_event("sync_product_uploads", _params, socket) do
    {:noreply, clear_flash(socket, :error)}
  end

  def handle_event("cancel-product-image", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :product_images, ref)}
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
      <section class="grid gap-6">
        <.section_intro
          id="new-product-heading"
          eyebrow="Inventory"
          title="New product intake"
          description="Step 1 of 2. Upload the product images first, then continue to the AI review form with recognized title, brand, and pricing suggestions."
        >
          <div class="mt-6 flex flex-wrap gap-3">
            <span class="badge badge-primary badge-lg">Step 1 · Upload images</span>
            <span class="badge badge-outline badge-lg">Step 2 · Review AI fields</span>
          </div>
        </.section_intro>

        <section class="grid gap-4 xl:grid-cols-[1fr_0.72fr]">
          <.surface id="new-product-upload-card" tag="article">
            <.header>
              Start with photos
              <:subtitle>
                Upload up to five images. ResellerIO will create the product, finalize the uploads, and start the AI pipeline automatically.
              </:subtitle>
            </.header>

            <.form
              for={@new_product_form}
              id="new-product-form"
              phx-change="sync_product_uploads"
              phx-submit="create_product"
            >
              <.input
                field={@new_product_form[:product_tab_id]}
                type="select"
                label="Tab"
                prompt="No tab"
                options={Helpers.product_tab_options(@product_tabs)}
              />

              <.upload_panel
                id="product-images-upload-panel"
                title="Product images"
                description="Use JPG, PNG, or WEBP photos. Upload progress stays in LiveView while Phoenix finalizes the product records."
                upload={@uploads.product_images}
                cancel_event="cancel-product-image"
                errors={Enum.map(upload_errors(@uploads.product_images), &error_to_string/1)}
              />

              <div class="mt-5 flex flex-wrap gap-3">
                <.button class="btn btn-primary rounded-full">Create draft from photos</.button>
                <.link navigate={~p"/app/products"} class="btn btn-ghost rounded-full">
                  Back to products
                </.link>
              </div>
            </.form>
          </.surface>

          <.surface tag="article" variant="soft">
            <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">What happens next</p>
            <div class="mt-5 space-y-4 text-sm leading-6 text-base-content/75">
              <div class="rounded-3xl border border-base-300 bg-base-100 px-4 py-4">
                <p class="font-semibold">Optional tab assignment</p>
                <p class="mt-1">
                  Assign this intake to a seller-defined tab now, or leave it unassigned and sort it later from the review page.
                </p>
              </div>
              <div class="rounded-3xl border border-base-300 bg-base-100 px-4 py-4">
                <p class="font-semibold">1. Product and image records are created</p>
                <p class="mt-1">
                  Upload metadata becomes `ProductImage` rows before the files are finalized.
                </p>
              </div>
              <div class="rounded-3xl border border-base-300 bg-base-100 px-4 py-4">
                <p class="font-semibold">2. AI recognizes the item and researches pricing</p>
                <p class="mt-1">
                  The review page refreshes while title, brand, summary, and pricing guidance arrive.
                </p>
              </div>
              <div class="rounded-3xl border border-base-300 bg-base-100 px-4 py-4">
                <p class="font-semibold">3. You confirm the final fields</p>
                <p class="mt-1">
                  Save the AI draft once you are satisfied with the title, category, price, and cost suggestions.
                </p>
              </div>
            </div>
          </.surface>
        </section>
      </section>
    </Layouts.app_shell>
    """
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

  defp checksum(binary), do: Base.encode16(:crypto.hash(:sha256, binary), case: :lower)

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
end
