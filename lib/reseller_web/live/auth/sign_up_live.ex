defmodule ResellerWeb.Auth.SignUpLive do
  use ResellerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Create Account",
       current_scope: nil,
       form: to_form(%{}, as: :user)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section class="relative overflow-hidden bg-base-100">
        <div class="reseller-hero-grid absolute inset-0 opacity-60"></div>
        <div class="reseller-orb absolute -left-12 top-12 size-72 rounded-full bg-primary/12 blur-3xl">
        </div>
        <div class="reseller-orb absolute right-8 top-16 size-64 rounded-full bg-secondary/12 blur-3xl [animation-delay:-5s]">
        </div>

        <div class="relative mx-auto grid min-h-[calc(100svh-73px)] max-w-7xl gap-10 px-4 py-12 sm:px-6 lg:grid-cols-[0.9fr_1.1fr] lg:items-center lg:px-8 lg:py-16">
          <div class="max-w-xl">
            <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
              Create your workspace
            </p>
            <h1 class="reseller-display mt-5 text-5xl font-semibold tracking-[-0.04em] text-balance sm:text-6xl">
              Start the web workflow for faster intake, clearer review, and cleaner listings.
            </h1>
            <p class="mt-6 text-base leading-7 text-base-content/72">
              Create an account to manage product drafts, image processing, and marketplace copy
              from one LiveView workspace.
            </p>

            <div class="mt-10 grid gap-3 text-sm text-base-content/72">
              <div class="rounded-[1.5rem] border border-base-300 bg-base-200/60 px-5 py-4">
                Upload sets of product photos without losing the originals.
              </div>
              <div class="rounded-[1.5rem] border border-base-300 bg-base-200/60 px-5 py-4">
                Review AI-generated details before anything becomes a finished listing.
              </div>
              <div class="rounded-[1.5rem] border border-base-300 bg-base-200/60 px-5 py-4">
                Prepare copy for eBay, Depop, and Poshmark in one place.
              </div>
            </div>
          </div>

          <div class="lg:justify-self-end lg:w-full lg:max-w-xl">
            <div class="rounded-[2rem] border border-base-300 bg-base-100/95 p-6 shadow-[0_28px_80px_rgba(20,20,20,0.12)] sm:p-8">
              <div class="mb-8">
                <p class="text-sm uppercase tracking-[0.3em] text-base-content/50">Sign up</p>
                <h2 class="mt-3 text-3xl font-semibold tracking-[-0.03em]">Create your account</h2>
              </div>

              <.form for={@form} id="sign-up-form" action={~p"/sign-up"} method="post">
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
                    autocomplete="new-password"
                  />

                  <button
                    id="sign-up-submit"
                    type="submit"
                    class="btn btn-primary btn-block rounded-full"
                  >
                    Create account
                  </button>
                </div>
              </.form>

              <p class="mt-6 text-sm text-base-content/65">
                Already have an account?
                <.link
                  navigate={~p"/sign-in"}
                  class="font-semibold text-primary hover:text-primary/80"
                >
                  Sign in
                </.link>
              </p>
            </div>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
