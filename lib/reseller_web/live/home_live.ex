defmodule ResellerWeb.HomeLive do
  use ResellerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: ResellerWeb.PageTitle.build("Home", "Marketing"),
       current_scope: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section
        id="home-hero"
        class="relative overflow-hidden border-b border-base-300/60 bg-base-100"
      >
        <div class="reseller-hero-grid absolute inset-0 opacity-70"></div>
        <div class="reseller-orb absolute -left-24 top-12 size-72 rounded-full bg-primary/18 blur-3xl">
        </div>
        <div class="reseller-orb absolute right-0 top-0 size-80 rounded-full bg-secondary/16 blur-3xl [animation-delay:-4s]">
        </div>
        <div class="reseller-orb absolute bottom-0 left-1/2 size-96 -translate-x-1/2 rounded-full bg-accent/12 blur-3xl [animation-delay:-8s]">
        </div>

        <div class="relative mx-auto grid min-h-[calc(100svh-73px)] max-w-7xl items-center gap-12 px-4 py-16 sm:px-6 lg:grid-cols-[minmax(0,1.05fr)_minmax(420px,0.95fr)] lg:px-8 lg:py-20">
          <div class="max-w-2xl">
            <.section_intro
              eyebrow="LiveView Resellerio workspace"
              title="Turn a pile of photos into clean listings ready for every market."
              description="Resellerio gives secondhand sellers one calm workspace for capture, AI-assisted product drafting, image cleanup, and marketplace-specific copy review."
              title_class="reseller-display mt-5 text-5xl font-semibold leading-[0.92] tracking-[-0.04em] text-balance sm:text-6xl lg:text-7xl"
              class="gap-0"
            >
              <p
                id="home-slogan"
                class="mt-4 text-sm font-semibold uppercase tracking-[0.32em] text-base-content/55"
              >
                Resellio · AI Inventory for Resellers
              </p>
              <div class="mt-10 flex flex-col gap-3 sm:flex-row">
                <%= if @current_user do %>
                  <.link
                    id="hero-primary-cta"
                    navigate={~p"/app"}
                    class="btn btn-primary btn-lg rounded-full px-7 transition-transform duration-300 hover:-translate-y-0.5"
                  >
                    Open workspace
                  </.link>
                <% else %>
                  <.link
                    id="hero-primary-cta"
                    navigate={~p"/sign-up"}
                    class="btn btn-primary btn-lg rounded-full px-7 transition-transform duration-300 hover:-translate-y-0.5"
                  >
                    Create account
                  </.link>
                <% end %>
                <a
                  id="hero-secondary-cta"
                  href="#launch"
                  class="btn btn-outline btn-lg rounded-full px-7"
                >
                  See The Web Flow
                </a>
              </div>
            </.section_intro>

            <div class="mt-12 flex flex-wrap gap-3 text-sm text-base-content/72">
              <span class="inline-flex items-center rounded-full border border-base-300 bg-base-200/80 px-4 py-3 font-medium">
                Tigris uploads
              </span>
              <span class="inline-flex items-center rounded-full border border-base-300 bg-base-200/80 px-4 py-3 font-medium">
                AI recognition
              </span>
              <span class="inline-flex items-center rounded-full border border-base-300 bg-base-200/80 px-4 py-3 font-medium">
                eBay / Depop / Poshmark
              </span>
            </div>
          </div>

          <div class="relative mx-auto w-full max-w-xl">
            <div class="absolute inset-x-8 top-8 h-40 rounded-full bg-primary/18 blur-3xl"></div>

            <div class="relative grid gap-4">
              <div class="reseller-photo rotate-[-8deg] rounded-[2rem] border border-base-300/70 bg-base-100/95 p-4 shadow-[0_30px_80px_rgba(20,20,20,0.12)]">
                <div class="aspect-[4/5] rounded-[1.5rem] bg-[radial-gradient(circle_at_top_left,_rgba(255,255,255,0.9),_rgba(255,255,255,0.25)_38%,_rgba(0,0,0,0)_42%),linear-gradient(160deg,_rgba(249,115,22,0.92),_rgba(217,70,239,0.7)_58%,_rgba(37,99,235,0.8))]">
                </div>
                <div class="mt-4 flex items-center justify-between text-sm">
                  <div>
                    <p class="font-semibold">Photo intake</p>
                    <p class="text-base-content/60">Drop images and create a product draft</p>
                  </div>
                  <span class="badge badge-primary badge-outline">Step 01</span>
                </div>
              </div>

              <div class="reseller-photo ml-auto w-[92%] rotate-[6deg] rounded-[2rem] border border-base-300/70 bg-base-100/95 p-4 shadow-[0_30px_80px_rgba(20,20,20,0.14)]">
                <div class="aspect-[16/10] rounded-[1.5rem] border border-base-300/70 bg-base-200/85 p-4">
                  <div class="flex items-center justify-between text-xs uppercase tracking-[0.28em] text-base-content/55">
                    <span>AI Draft</span>
                    <span class="badge badge-warning badge-sm">Review</span>
                  </div>
                  <div class="mt-5 space-y-3">
                    <div class="h-3 w-4/5 rounded-full bg-primary/30"></div>
                    <div class="h-3 w-2/3 rounded-full bg-secondary/30"></div>
                    <div class="grid grid-cols-2 gap-3 pt-4">
                      <div class="rounded-2xl bg-base-100 p-3">
                        <p class="text-xs uppercase tracking-[0.25em] text-base-content/50">Brand</p>
                        <p class="mt-2 font-medium">Vintage Leather</p>
                      </div>
                      <div class="rounded-2xl bg-base-100 p-3">
                        <p class="text-xs uppercase tracking-[0.25em] text-base-content/50">
                          Condition
                        </p>
                        <p class="mt-2 font-medium">Very good</p>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="mt-4 flex items-center justify-between text-sm">
                  <div>
                    <p class="font-semibold">Structured review</p>
                    <p class="text-base-content/60">
                      Check titles, tags, price signals, and confidence
                    </p>
                  </div>
                  <span class="badge badge-secondary badge-outline">Step 02</span>
                </div>
              </div>

              <div class="reseller-photo rounded-[2rem] border border-base-300/70 bg-neutral p-4 text-neutral-content shadow-[0_30px_80px_rgba(20,20,20,0.18)]">
                <div class="grid gap-4 md:grid-cols-[1.1fr_0.9fr]">
                  <div class="space-y-3 rounded-[1.5rem] bg-white/6 p-5">
                    <p class="text-xs uppercase tracking-[0.3em] text-neutral-content/60">Markets</p>
                    <p class="reseller-display text-3xl leading-tight">
                      One product, tuned for each storefront.
                    </p>
                    <p class="text-sm text-neutral-content/72">
                      Draft listing copy for eBay, Depop, and Poshmark without retyping the same story.
                    </p>
                  </div>
                  <div class="grid gap-3">
                    <div class="rounded-[1.25rem] bg-white/8 p-4">
                      <p class="text-sm font-semibold">eBay</p>
                      <p class="mt-2 text-xs text-neutral-content/70">
                        Structured title + condition details
                      </p>
                    </div>
                    <div class="rounded-[1.25rem] bg-white/8 p-4">
                      <p class="text-sm font-semibold">Depop</p>
                      <p class="mt-2 text-xs text-neutral-content/70">Style-forward tone + tags</p>
                    </div>
                    <div class="rounded-[1.25rem] bg-white/8 p-4">
                      <p class="text-sm font-semibold">Poshmark</p>
                      <p class="mt-2 text-xs text-neutral-content/70">
                        Concise copy + buyer-friendly highlights
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="workflow" class="border-b border-base-300/60 bg-base-200/45">
        <div class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8 lg:py-20">
          <div class="grid gap-8 lg:grid-cols-[0.9fr_1.1fr] lg:items-start">
            <.section_intro
              eyebrow="Workflow"
              title="Built for the messy reality of resale, not pristine catalog studios."
              description="The web version is the wide-screen control room: upload, review, adjust, and push each product toward a ready-to-list state without losing the original image set."
              title_class="reseller-display mt-4 text-4xl font-semibold tracking-[-0.03em] text-balance"
              class="gap-0"
            />

            <div class="grid gap-4 md:grid-cols-3">
              <.feature_tile
                eyebrow="Capture"
                title="Upload multiple photos fast"
                description="Drag in a full set, keep the originals, and let the product draft begin while you move to the next item."
                accent="primary"
              />

              <.feature_tile
                eyebrow="Refine"
                title="Review AI before it goes live"
                description="Inspect extracted fields, confidence signals, and generated copy before accepting the final version."
                accent="secondary"
              />

              <.feature_tile
                id="markets"
                eyebrow="Publish"
                title="Shape listings for each market"
                description="Keep one product record, then tune descriptions for the rules and tone of each resale channel."
                accent="accent"
              />
            </div>
          </div>
        </div>
      </section>

      <section id="launch" class="bg-base-100">
        <div class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8 lg:py-20">
          <.surface
            tag="div"
            variant="ghost"
            padding="xl"
            class="grid gap-8 rounded-[2.25rem] lg:grid-cols-[1fr_auto] lg:items-center"
          >
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">Next up</p>
              <h2
                id="home-final-cta"
                class="reseller-display mt-4 text-4xl font-semibold tracking-[-0.03em] text-balance"
              >
                The landing page is ready. Browser auth and the Resellerio dashboard are next.
              </h2>
              <p class="mt-4 max-w-2xl text-base leading-7 text-base-content/70">
                This first web checkpoint establishes the visual direction and LiveView shell. The
                next implementation steps add sign-in, sign-up, and the authenticated product
                workspace.
              </p>
            </div>

            <div class="flex flex-col gap-3 sm:flex-row lg:flex-col">
              <%= if @current_user do %>
                <.link navigate={~p"/app"} class="btn btn-primary rounded-full px-7">
                  Open workspace
                </.link>
              <% else %>
                <.link navigate={~p"/sign-up"} class="btn btn-primary rounded-full px-7">
                  Create account
                </.link>
              <% end %>
              <a href="#home-hero" class="btn btn-ghost rounded-full px-7">Back to top</a>
            </div>
          </.surface>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
