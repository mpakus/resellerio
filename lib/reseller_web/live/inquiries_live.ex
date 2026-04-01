defmodule ResellerWeb.InquiriesLive do
  use ResellerWeb, :live_view

  alias Reseller.Storefronts
  alias ResellerWeb.WorkspaceNavigation

  @page_size 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: ResellerWeb.PageTitle.build("Inquiries", "Workspace"),
       workspace_nav: WorkspaceNavigation.items(:inquiries),
       inquiries: [],
       total_count: 0,
       total_pages: 1,
       page: 1,
       query: nil,
       search_form: to_form(%{"query" => ""}, as: :search)
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    page = parse_positive_integer(Map.get(params, "page"), 1)
    query = normalize_query(Map.get(params, "q"))

    result =
      Storefronts.list_inquiries_for_user(socket.assigns.current_user,
        page: page,
        page_size: @page_size,
        query: query
      )

    {:noreply,
     assign(socket,
       inquiries: result.entries,
       total_count: result.total_count,
       total_pages: result.total_pages,
       page: result.page,
       query: query,
       search_form: to_form(%{"query" => query || ""}, as: :search)
     )}
  end

  @impl true
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/app/inquiries?#{build_params(%{q: normalize_query(query), page: 1})}"
     )}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/app/inquiries")}
  end

  def handle_event("delete_inquiry", %{"id" => id}, socket) do
    case Storefronts.delete_inquiry_for_user(socket.assigns.current_user, id) do
      {:ok, _inquiry} ->
        result =
          Storefronts.list_inquiries_for_user(socket.assigns.current_user,
            page: socket.assigns.page,
            page_size: @page_size,
            query: socket.assigns.query
          )

        {:noreply,
         socket
         |> assign(
           inquiries: result.entries,
           total_count: result.total_count,
           total_pages: result.total_pages,
           page: result.page
         )
         |> put_flash(:info, "Inquiry deleted.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Inquiry not found.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app_shell
      flash={@flash}
      current_user={@current_user}
      workspace_nav={@workspace_nav}
    >
      <section class="grid gap-8">
        <div class="grid gap-4 lg:grid-cols-[1.1fr_0.9fr] lg:items-end">
          <.section_intro
            id="inquiries-heading"
            eyebrow="Storefront"
            title="Inquiries from visitors."
            description="Requests submitted through your public storefront product pages. Delete entries you no longer need."
            title_class="reseller-display mt-4 text-5xl font-semibold tracking-[-0.04em] text-balance"
            class="gap-0"
          />

          <.surface tag="div" class="rounded-[2rem]">
            <p class="text-xs uppercase tracking-[0.3em] text-base-content/50">Summary</p>
            <p id="inquiries-total-count" class="mt-4 text-2xl font-semibold tracking-[-0.03em]">
              {@total_count} total
            </p>
            <p class="mt-2 text-sm text-base-content/65">
              Inquiries matching the current filter across all your storefront products.
            </p>
          </.surface>
        </div>

        <.surface tag="section">
          <div class="flex flex-wrap items-center justify-between gap-4">
            <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">All inquiries</p>

            <.form
              for={@search_form}
              id="inquiries-search-form"
              phx-submit="search"
              phx-change="search"
              class="flex gap-2"
            >
              <input
                type="search"
                name="search[query]"
                value={@search_form[:query].value}
                placeholder="Search name, contact, message…"
                class="input input-bordered input-sm rounded-full w-64"
                phx-debounce="400"
              />
              <button
                :if={@query}
                type="button"
                phx-click="clear_search"
                class="btn btn-ghost btn-sm rounded-full"
              >
                Clear
              </button>
            </.form>
          </div>

          <div class="mt-6 space-y-3">
            <div
              :if={@inquiries == []}
              class="rounded-[1.5rem] border border-dashed border-base-300 bg-base-50 px-4 py-8 text-center text-sm text-base-content/60"
            >
              <%= if @query do %>
                No inquiries match <span class="font-medium">"{@query}"</span>.
              <% else %>
                No inquiries yet. They appear here when visitors submit requests from your storefront.
              <% end %>
            </div>

            <div
              :for={inquiry <- @inquiries}
              id={"inquiry-#{inquiry.id}"}
              class="rounded-[1.6rem] border border-base-300 bg-base-50 px-5 py-4"
            >
              <div class="flex flex-wrap items-start justify-between gap-4">
                <div class="min-w-0 flex-1 grid gap-1">
                  <div class="flex flex-wrap items-center gap-2">
                    <p class="text-sm font-semibold">{inquiry.full_name}</p>
                    <span class="text-base-content/40">·</span>
                    <p class="text-sm text-base-content/70">{inquiry.contact}</p>
                  </div>

                  <p
                    :if={inquiry.product}
                    class="text-xs uppercase tracking-[0.18em] text-base-content/45"
                  >
                    Re: {inquiry.product.title || "Untitled product"}
                  </p>

                  <p class="mt-2 text-sm leading-6 text-base-content/80">
                    {inquiry.message}
                  </p>

                  <div class="mt-2 flex flex-wrap items-center gap-3">
                    <span class="text-xs text-base-content/45">
                      {format_datetime(inquiry.inserted_at)}
                    </span>
                    <a
                      :if={inquiry.source_path}
                      href={inquiry.source_path}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="inline-flex items-center gap-1 text-xs text-base-content/35 hover:text-base-content/60 truncate max-w-[240px] transition-colors"
                    >
                      {inquiry.source_path}
                      <.icon name="hero-arrow-top-right-on-square" class="size-3 shrink-0" />
                    </a>
                  </div>
                </div>

                <button
                  type="button"
                  phx-click="delete_inquiry"
                  phx-value-id={inquiry.id}
                  data-confirm="Delete this inquiry? This cannot be undone."
                  class="btn btn-ghost btn-xs rounded-full text-error shrink-0"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>

          <div :if={@total_pages > 1} class="mt-6 flex flex-wrap items-center justify-center gap-2">
            <.link
              :if={@page > 1}
              patch={~p"/app/inquiries?#{build_params(%{q: @query, page: @page - 1})}"}
              class="btn btn-outline btn-sm rounded-full"
            >
              Previous
            </.link>

            <span class="text-sm text-base-content/60">
              Page {@page} of {@total_pages}
            </span>

            <.link
              :if={@page < @total_pages}
              patch={~p"/app/inquiries?#{build_params(%{q: @query, page: @page + 1})}"}
              class="btn btn-outline btn-sm rounded-full"
            >
              Next
            </.link>
          </div>
        </.surface>
      </section>
    </Layouts.app_shell>
    """
  end

  defp parse_positive_integer(nil, default), do: default

  defp parse_positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 -> n
      _other -> default
    end
  end

  defp parse_positive_integer(_, default), do: default

  defp normalize_query(nil), do: nil

  defp normalize_query(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      v -> v
    end
  end

  defp build_params(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp format_datetime(nil), do: "—"
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
end
