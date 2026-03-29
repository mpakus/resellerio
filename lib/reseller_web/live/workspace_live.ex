defmodule ResellerWeb.WorkspaceLive do
  use ResellerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Workspace", current_scope: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app_shell flash={@flash} current_user={@current_user}>
      <section class="grid gap-8">
        <div class="grid gap-4 lg:grid-cols-[1.05fr_0.95fr] lg:items-end">
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
              Authenticated shell
            </p>
            <h1
              id="workspace-heading"
              class="reseller-display mt-4 text-5xl font-semibold tracking-[-0.04em] text-balance"
            >
              Your reseller workspace is ready for the next product screens.
            </h1>
            <p class="mt-5 max-w-2xl text-base leading-7 text-base-content/70">
              Browser auth now lands inside a protected LiveView shell. The next web milestone
              fills this workspace with the real dashboard, inventory lists, and upload-driven
              product intake.
            </p>
          </div>

          <div class="rounded-[2rem] border border-base-300 bg-base-100 p-6 shadow-[0_24px_70px_rgba(20,20,20,0.08)]">
            <p class="text-xs uppercase tracking-[0.3em] text-base-content/50">Current user</p>
            <p id="workspace-user-email" class="mt-4 text-2xl font-semibold tracking-[-0.03em]">
              {@current_user.email}
            </p>
            <p class="mt-2 text-sm text-base-content/65">
              Browser session is active and protected routes are now ready.
            </p>
          </div>
        </div>

        <div class="grid gap-4 xl:grid-cols-3">
          <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
            <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Dashboard next</p>
            <p class="mt-4 text-2xl font-semibold tracking-[-0.03em]">Operational overview</p>
            <p class="mt-3 text-sm leading-6 text-base-content/68">
              Processing queues, recent products, export activity, and quick actions will live here.
            </p>
          </article>

          <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
            <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Inventory next</p>
            <p class="mt-4 text-2xl font-semibold tracking-[-0.03em]">Catalog surfaces</p>
            <p class="mt-3 text-sm leading-6 text-base-content/68">
              Products, statuses, review states, and marketplace readiness will become first-class
              screens inside this shell.
            </p>
          </article>

          <article class="rounded-[1.75rem] border border-base-300 bg-base-100 p-6">
            <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Uploads next</p>
            <p class="mt-4 text-2xl font-semibold tracking-[-0.03em]">Photo intake flow</p>
            <p class="mt-3 text-sm leading-6 text-base-content/68">
              The protected shell now gives us the right place to add signed uploads and AI review
              without rebuilding auth again.
            </p>
          </article>
        </div>
      </section>
    </Layouts.app_shell>
    """
  end
end
