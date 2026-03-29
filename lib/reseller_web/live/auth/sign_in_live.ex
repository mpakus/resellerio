defmodule ResellerWeb.Auth.SignInLive do
  use ResellerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Sign In",
       current_scope: nil,
       form: to_form(%{}, as: :session)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section class="relative overflow-hidden bg-base-100">
        <div class="reseller-hero-grid absolute inset-0 opacity-60"></div>
        <div class="reseller-orb absolute left-0 top-10 size-72 rounded-full bg-primary/12 blur-3xl [animation-delay:-7s]">
        </div>
        <div class="reseller-orb absolute bottom-10 right-0 size-80 rounded-full bg-accent/12 blur-3xl [animation-delay:-3s]">
        </div>

        <div class="relative mx-auto grid min-h-[calc(100svh-73px)] max-w-7xl gap-10 px-4 py-12 sm:px-6 lg:grid-cols-[1fr_0.95fr] lg:items-center lg:px-8 lg:py-16">
          <div class="order-2 lg:order-1 lg:justify-self-start lg:w-full lg:max-w-xl">
            <div class="rounded-[2rem] border border-base-300 bg-base-100/95 p-6 shadow-[0_28px_80px_rgba(20,20,20,0.12)] sm:p-8">
              <div class="mb-8">
                <p class="text-sm uppercase tracking-[0.3em] text-base-content/50">Sign in</p>
                <h1 class="mt-3 text-3xl font-semibold tracking-[-0.03em]">
                  Return to your reseller workspace
                </h1>
              </div>

              <.form for={@form} id="sign-in-form" action={~p"/sign-in"} method="post">
                <div class="space-y-5">
                  <.input
                    field={@form[:email]}
                    type="email"
                    label="Email"
                    required
                    autocomplete="email"
                  />
                  <.input
                    field={@form[:password]}
                    type="password"
                    label="Password"
                    required
                    autocomplete="current-password"
                  />

                  <button
                    id="sign-in-submit"
                    type="submit"
                    class="btn btn-primary btn-block rounded-full"
                  >
                    Sign in
                  </button>
                </div>
              </.form>

              <p class="mt-6 text-sm text-base-content/65">
                Need an account?
                <.link
                  navigate={~p"/sign-up"}
                  class="font-semibold text-primary hover:text-primary/80"
                >
                  Create one
                </.link>
              </p>
            </div>
          </div>

          <div class="order-1 max-w-xl lg:order-2">
            <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
              Sign in fast
            </p>
            <h2 class="reseller-display mt-5 text-5xl font-semibold tracking-[-0.04em] text-balance sm:text-6xl">
              Pick up where the product queue left off.
            </h2>
            <p class="mt-6 text-base leading-7 text-base-content/72">
              Review items waiting for AI confirmation, continue image cleanup, and keep marketplace
              drafts moving without re-entering the same product details.
            </p>

            <div class="mt-10 grid gap-4 sm:grid-cols-3">
              <div class="rounded-[1.5rem] border border-base-300 bg-base-200/60 p-5">
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Queue</p>
                <p class="mt-3 text-lg font-semibold">Drafts in progress</p>
              </div>
              <div class="rounded-[1.5rem] border border-base-300 bg-base-200/60 p-5">
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Review</p>
                <p class="mt-3 text-lg font-semibold">AI confidence checks</p>
              </div>
              <div class="rounded-[1.5rem] border border-base-300 bg-base-200/60 p-5">
                <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">Markets</p>
                <p class="mt-3 text-lg font-semibold">Listing variants</p>
              </div>
            </div>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
