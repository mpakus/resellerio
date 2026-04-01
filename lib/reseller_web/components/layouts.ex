defmodule ResellerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ResellerWeb, :html
  import ResellerWeb.StorefrontComponents

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, :map, default: nil, doc: "the current signed in user"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-100 text-base-content">
      <header class="sticky top-0 z-40 border-b border-base-300/60 bg-base-100/85 backdrop-blur">
        <div class="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
          <.link navigate={~p"/"} class="flex items-center gap-3">
            <div class="flex size-11 items-center justify-center overflow-hidden">
              <img src="/images/logo.png" alt="ResellerIO" class="size-full object-contain" />
            </div>
            <div>
              <p class="reseller-display text-xl font-semibold leading-none">ResellerIO</p>
              <p class="text-xs uppercase tracking-[0.28em] text-base-content/55">AI Inventory</p>
            </div>
          </.link>

          <div class="hidden items-center gap-3 md:flex">
            <a href="#workflow" class="btn btn-ghost btn-sm rounded-full">Workflow</a>
            <a href="#features" class="btn btn-ghost btn-sm rounded-full">Features</a>
            <a href="#lifestyle" class="btn btn-ghost btn-sm rounded-full">Lifestyle AI</a>
            <a href="#marketplace-strip" class="btn btn-ghost btn-sm rounded-full">Markets</a>
            <a href="#storefront" class="btn btn-ghost btn-sm rounded-full">Storefront</a>
            <%= if @current_user do %>
              <.link navigate={~p"/app"} class="btn btn-ghost btn-sm rounded-full">Workspace</.link>
              <%= if @current_user.is_admin do %>
                <a href="/admin/users/" class="btn btn-ghost btn-sm rounded-full">Admin</a>
              <% end %>
              <.link href={~p"/sign-out"} method="delete" class="btn btn-primary btn-sm rounded-full">
                Sign out
              </.link>
            <% else %>
              <.link navigate={~p"/sign-in"} class="btn btn-ghost btn-sm rounded-full">Sign in</.link>
              <.link navigate={~p"/sign-up"} class="btn btn-primary btn-sm rounded-full">
                Create account
              </.link>
            <% end %>
            <.theme_toggle />
          </div>

          <div class="flex items-center gap-2 md:hidden">
            <%= if @current_user do %>
              <.link navigate={~p"/app"} class="btn btn-ghost btn-sm rounded-full">App</.link>
              <%= if @current_user.is_admin do %>
                <a href="/admin/users/" class="btn btn-outline btn-sm rounded-full">Admin</a>
              <% end %>
              <.link href={~p"/sign-out"} method="delete" class="btn btn-primary btn-sm rounded-full">
                Out
              </.link>
            <% else %>
              <.link navigate={~p"/sign-in"} class="btn btn-ghost btn-sm rounded-full">Sign in</.link>
            <% end %>
            <a href={~p"/api/v1"} class="btn btn-outline btn-sm rounded-full">API</a>
            <.theme_toggle />
          </div>
        </div>
      </header>

      <main>{render_slot(@inner_block)}</main>

      <footer class="border-t border-base-300/60 bg-base-200/40">
        <div class="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4 px-4 py-6 text-sm text-base-content/55 sm:px-6 lg:px-8">
          <a
            href="https://scaledfactorialproduct.com"
            target="_blank"
            rel="noopener noreferrer"
            class="hover:text-base-content transition-colors"
          >
            Built by humans in Austin✩Texas
          </a>
          <a href={~p"/privacy"} class="hover:text-base-content transition-colors">Privacy Policy</a>
          <a href={~p"/dpa"} class="hover:text-base-content transition-colors">DPA</a>
          <.link navigate={~p"/docs/api"} class="hover:text-base-content transition-colors">API Docs</.link>
          <a href={~p"/api/v1"} class="hover:text-base-content transition-colors">API v1</a>
          <a href="https://made-by-human.com" target="_blank" rel="noopener noreferrer">
            <img
              src="https://made-by-human.com/images/human29.png"
              alt="made by human"
              class="h-8 w-auto opacity-80 hover:opacity-100 transition-opacity"
            />
          </a>
        </div>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :flash, :map, required: true
  attr :storefront, :map, required: true
  attr :current_user, :map, default: nil
  attr :query, :string, default: nil
  attr :active_nav, :string, default: "catalog"
  slot :inner_block, required: true

  def storefront(assigns) do
    assigns =
      assigns
      |> assign(:logo_url, storefront_logo_url(assigns.storefront))
      |> assign(:header_url, storefront_header_url(assigns.storefront))
      |> assign(:nav_pages, storefront_nav_pages(assigns.storefront))

    ~H"""
    <div
      id="storefront-shell"
      class="min-h-screen bg-[var(--storefront-page-bg)] text-[var(--storefront-text)]"
      style={storefront_theme_style(@storefront)}
    >
      <header class="relative isolate overflow-hidden border-b border-[var(--storefront-border)]">
        <div
          :if={@header_url}
          class="absolute inset-0 -z-10 overflow-hidden opacity-20"
        >
          <img src={@header_url} alt="" class="size-full object-cover" />
          <div class="absolute inset-0 bg-white/50"></div>
        </div>
        <div
          class="pointer-events-none absolute inset-x-0 top-0 -z-10 h-72"
          style="background: radial-gradient(circle at top, var(--storefront-overlay), transparent 72%);"
        >
        </div>

        <div class="mx-auto flex max-w-7xl flex-col gap-6 px-4 py-6 sm:px-6 lg:px-8">
          <div class="flex flex-wrap items-center justify-between gap-4">
            <div class="flex min-w-0 items-center gap-4">
              <div
                :if={@logo_url}
                class="flex size-14 shrink-0 items-center justify-center overflow-hidden rounded-[1.4rem] border border-[var(--storefront-border)] bg-white/70 shadow-[0_18px_45px_rgba(15,23,42,0.08)]"
              >
                <img
                  src={@logo_url}
                  alt={"#{@storefront.title} logo"}
                  class="size-full object-cover"
                />
              </div>

              <div class="min-w-0">
                <p class="text-[11px] uppercase tracking-[0.34em] text-[var(--storefront-muted)]">
                  Reseller storefront
                </p>
                <.link
                  href={~p"/store/#{@storefront.slug}"}
                  class="reseller-display mt-2 block truncate text-3xl font-semibold tracking-[-0.04em] text-[var(--storefront-text)]"
                >
                  {@storefront.title}
                </.link>
                <p
                  :if={@storefront.tagline}
                  class="mt-2 max-w-2xl truncate text-sm text-[var(--storefront-muted)]"
                >
                  {@storefront.tagline}
                </p>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <.link
                href={~p"/"}
                class="rounded-full border border-[var(--storefront-border)] px-4 py-2 text-sm font-medium text-[var(--storefront-text)] transition hover:bg-white/60"
              >
                ResellerIO
              </.link>
              <%= if @current_user do %>
                <.link
                  href={~p"/app"}
                  class="rounded-full px-4 py-2 text-sm font-semibold text-white shadow-[0_16px_35px_rgba(15,23,42,0.18)]"
                  style="background-color: var(--storefront-primary);"
                >
                  Workspace
                </.link>
              <% else %>
                <.link
                  href={~p"/sign-in"}
                  class="rounded-full px-4 py-2 text-sm font-semibold text-white shadow-[0_16px_35px_rgba(15,23,42,0.18)]"
                  style="background-color: var(--storefront-primary);"
                >
                  Sign in
                </.link>
              <% end %>
            </div>
          </div>

          <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <nav
              id="storefront-nav"
              class="flex flex-wrap items-center gap-2 text-sm"
              aria-label="Storefront navigation"
            >
              <.link
                href={~p"/store/#{@storefront.slug}"}
                class={[
                  "rounded-full border px-4 py-2 font-medium transition",
                  @active_nav == "catalog" &&
                    "border-transparent text-white shadow-[0_14px_30px_rgba(15,23,42,0.14)]",
                  @active_nav != "catalog" &&
                    "border-[var(--storefront-border)] text-[var(--storefront-text)] hover:bg-white/60"
                ]}
                style={
                  if @active_nav == "catalog", do: "background-color: var(--storefront-primary);"
                }
              >
                Catalog
              </.link>

              <.link
                :for={page <- @nav_pages}
                href={storefront_page_path(@storefront, page)}
                class={[
                  "rounded-full border px-4 py-2 font-medium transition",
                  @active_nav == page.slug &&
                    "border-transparent text-white shadow-[0_14px_30px_rgba(15,23,42,0.14)]",
                  @active_nav != page.slug &&
                    "border-[var(--storefront-border)] text-[var(--storefront-text)] hover:bg-white/60"
                ]}
                style={
                  if @active_nav == page.slug, do: "background-color: var(--storefront-primary);"
                }
              >
                {page.menu_label}
              </.link>
            </nav>

            <form
              id="storefront-search-form"
              action={~p"/store/#{@storefront.slug}"}
              method="get"
              class="flex w-full max-w-xl items-center gap-3 rounded-[1.4rem] border border-[var(--storefront-border)] bg-white/65 px-4 py-3 shadow-[0_18px_45px_rgba(15,23,42,0.06)]"
            >
              <.icon
                name="hero-magnifying-glass"
                class="size-5 shrink-0 text-[var(--storefront-muted)]"
              />
              <input
                id="storefront-search"
                type="search"
                name="q"
                value={@query}
                placeholder="Search titles, brands, categories, and notes"
                class="w-full bg-transparent text-sm text-[var(--storefront-text)] outline-none placeholder:text-[var(--storefront-muted)]"
              />
              <button
                type="submit"
                class="rounded-full px-4 py-2 text-sm font-semibold text-white shadow-[0_14px_30px_rgba(15,23,42,0.14)]"
                style="background-color: var(--storefront-primary);"
              >
                Search
              </button>
            </form>
          </div>
        </div>
      </header>

      <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8 lg:py-10">
        {render_slot(@inner_block)}
      </main>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_user, :map, required: true, doc: "the current signed in user"
  attr :workspace_nav, :list, default: [], doc: "workspace navigation items"
  attr :nav_mode, :atom, default: :navigate, values: [:navigate, :patch]
  slot :inner_block, required: true

  def app_shell(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200/45 text-base-content lg:grid lg:grid-cols-[280px_1fr]">
      <aside class="hidden border-r border-base-300 bg-base-100 lg:flex lg:flex-col">
        <div class="border-b border-base-300 px-6 py-6">
          <p class="reseller-display text-3xl font-semibold tracking-[-0.03em]">ResellerIO</p>
          <p class="mt-2 text-xs uppercase tracking-[0.3em] text-base-content/50">Workspace shell</p>
        </div>

        <nav class="flex-1 px-4 py-6">
          <ul class="menu gap-2 rounded-box bg-base-100 p-0">
            <li :for={item <- @workspace_nav}>
              <%= if (item[:mode] || @nav_mode) == :patch do %>
                <.link
                  patch={item.path}
                  class={[
                    "rounded-2xl transition-colors",
                    item.active && "active bg-base-200 font-medium"
                  ]}
                >
                  {item.label}
                </.link>
              <% else %>
                <.link
                  navigate={item.path}
                  class={[
                    "rounded-2xl transition-colors",
                    item.active && "active bg-base-200 font-medium"
                  ]}
                >
                  {item.label}
                </.link>
              <% end %>
            </li>
            <li :if={@current_user.is_admin}>
              <a
                href="/admin/users/"
                class="rounded-2xl transition-colors text-base-content/60 hover:text-base-content"
              >
                Admin
              </a>
            </li>
            <li>
              <a
                href="/"
                class="rounded-2xl transition-colors text-base-content/60 hover:text-base-content"
              >
                Home
              </a>
            </li>
          </ul>
        </nav>

        <div class="border-t border-base-300 px-6 py-6">
          <p class="text-xs uppercase tracking-[0.3em] text-base-content/50">Signed in</p>
          <p class="mt-3 text-sm font-semibold">{@current_user.email}</p>
          <a
            :if={@current_user.is_admin}
            href="/admin/users/"
            class="btn btn-outline btn-sm mt-5 rounded-full"
          >
            Open admin
          </a>
          <.link href={~p"/sign-out"} method="delete" class="btn btn-primary btn-sm mt-5 rounded-full">
            Sign out
          </.link>
        </div>
      </aside>

      <div class="min-w-0">
        <header class="border-b border-base-300 bg-base-100/80 backdrop-blur">
          <div class="mx-auto flex max-w-7xl items-center justify-between gap-4 px-4 py-4 sm:px-6 lg:px-8">
            <div class="ml-auto flex items-center gap-2">
              <span class="hidden rounded-full border border-base-300 bg-base-200 px-3 py-1 text-sm text-base-content/70 sm:inline-flex">
                {@current_user.email}
              </span>
              <.theme_toggle />
            </div>
          </div>
        </header>

        <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
          {render_slot(@inner_block)}
        </main>

        <.flash_group flash={@flash} />
      </div>
    </div>
    """
  end

  attr :flash, :map, required: true
  attr :current_user, :map, required: true
  attr :current_url, :string, required: true
  attr :live_resource, :any, required: true
  attr :fluid?, :boolean, default: false
  slot :inner_block, required: true

  def admin(assigns) do
    ~H"""
    <Backpex.HTML.Layout.app_shell live_resource={@live_resource} fluid={@fluid?}>
      <:topbar>
        <div class="flex min-w-0 flex-1 items-center justify-between gap-4">
          <div class="min-w-0">
            <p class="text-xs uppercase tracking-[0.3em] text-base-content/50">Admin interface</p>
            <p class="truncate text-sm font-semibold">{@current_user.email}</p>
          </div>

          <div class="flex items-center gap-2">
            <.link navigate={~p"/app"} class="btn btn-ghost btn-sm rounded-full">Workspace</.link>
            <.link href={~p"/sign-out"} method="delete" class="btn btn-primary btn-sm rounded-full">
              Sign out
            </.link>
          </div>
        </div>
      </:topbar>

      <:sidebar>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/admin/users/">
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-users" class="size-4" /> Users
          </span>
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/admin/api-tokens/">
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-key" class="size-4" /> API Tokens
          </span>
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/admin/products/">
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-squares-2x2" class="size-4" /> Products
          </span>
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/admin/storefronts/">
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-building-storefront" class="size-4" /> Storefronts
          </span>
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item
          current_url={@current_url}
          navigate="/admin/api-usage-events/"
        >
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-chart-bar" class="size-4" /> API Events
          </span>
        </Backpex.HTML.Layout.sidebar_item>
        <Backpex.HTML.Layout.sidebar_item current_url={@current_url} navigate="/admin/usage-dashboard">
          <span class="inline-flex items-center gap-2">
            <.icon name="hero-presentation-chart-line" class="size-4" /> Usage Dashboard
          </span>
        </Backpex.HTML.Layout.sidebar_item>
      </:sidebar>

      {render_slot(@inner_block)}
      <Backpex.HTML.Layout.flash_messages flash={@flash} />
    </Backpex.HTML.Layout.app_shell>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
