defmodule ResellerWeb.HomeLive do
  use ResellerWeb, :live_view

  @pics ~w(pic01.png pic02.png pic03.png pic04.png)
  @imgs ~w(img01.png img02.png img03.png img04.png img05.png img06.png)

  @typing_phrases [
    "a vintage leather jacket",
    "Nike Air Max 90s",
    "a Y2K denim skirt",
    "Levi's 501 jeans",
    "a Coach crossbody bag",
    "retro New Balance 574s",
    "an oversized Polo hoodie"
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :tick_typing, 80)
      Process.send_after(self(), :tick_stats, 800)
    end

    {:ok,
     assign(socket,
       page_title: ResellerWeb.PageTitle.build("Home", "Marketing"),
       current_scope: nil,
       hero_pic: Enum.random(@pics),
       storefront_imgs: Enum.shuffle(@imgs),
       typing_text: "",
       typing_phrase_idx: 0,
       typing_char_idx: 0,
       typing_deleting: false,
       typing_pause: 0,
       stat_products: 0,
       stat_markets: 0,
       stat_time: 0,
       stat_images: 0,
       stats_step: 0
     )}
  end

  @stats_targets %{products: 12_400, markets: 12, time: 90, images: 3}
  @stats_steps 40

  @impl true
  def handle_info(:tick_typing, socket) do
    phrases = @typing_phrases
    idx = socket.assigns.typing_phrase_idx
    phrase = Enum.at(phrases, idx)
    char_idx = socket.assigns.typing_char_idx
    deleting = socket.assigns.typing_deleting
    pause = socket.assigns.typing_pause

    {next_text, next_char, next_del, next_idx, next_pause, delay} =
      cond do
        pause > 0 ->
          {String.slice(phrase, 0, char_idx), char_idx, deleting, idx, pause - 1, 60}

        not deleting and char_idx < String.length(phrase) ->
          {String.slice(phrase, 0, char_idx + 1), char_idx + 1, false, idx, 0, 55}

        not deleting and char_idx == String.length(phrase) ->
          {phrase, char_idx, true, idx, 22, 60}

        deleting and char_idx > 0 ->
          {String.slice(phrase, 0, char_idx - 1), char_idx - 1, true, idx, 0, 32}

        deleting and char_idx == 0 ->
          next = rem(idx + 1, length(phrases))
          {"", 0, false, next, 6, 60}
      end

    Process.send_after(self(), :tick_typing, delay)

    {:noreply,
     assign(socket,
       typing_text: next_text,
       typing_char_idx: next_char,
       typing_deleting: next_del,
       typing_phrase_idx: next_idx,
       typing_pause: next_pause
     )}
  end

  @impl true
  def handle_info(:tick_stats, socket) do
    step = socket.assigns.stats_step + 1
    t = @stats_targets
    ease = 1 - :math.pow(1 - step / @stats_steps, 3)

    if step <= @stats_steps do
      Process.send_after(self(), :tick_stats, 30)
    end

    {:noreply,
     assign(socket,
       stats_step: step,
       stat_products: round(t.products * ease),
       stat_markets: round(t.markets * ease),
       stat_time: round(t.time * ease),
       stat_images: round(t.images * ease)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <%!-- HERO --%>
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
            <p class="text-sm font-semibold uppercase tracking-[0.32em] text-primary">
              AI Inventory for Resellers
            </p>
            <h1 class="reseller-display mt-5 text-5xl font-semibold leading-[0.92] tracking-[-0.04em] text-balance sm:text-6xl lg:text-7xl">
              List <span class="text-primary reseller-cursor">{@typing_text}</span>
              <br />in minutes, not hours.
            </h1>
            <p class="mt-6 max-w-xl text-lg leading-7 text-base-content/68">
              ResellerIO gives secondhand sellers one powerful platform — photo capture, AI product drafting, image cleanup, background removal, AR lifestyle shots, and marketplace-specific copy, all in one place.
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
                  Start for free
                </.link>
              <% end %>
              <a
                id="hero-secondary-cta"
                href="#features"
                class="btn btn-outline btn-lg rounded-full px-7"
              >
                See all features
              </a>
            </div>

            <div class="mt-12 flex flex-wrap gap-3 text-sm text-base-content/72">
              <span class="reseller-shimmer inline-flex items-center rounded-full border border-base-300 bg-base-200/80 px-4 py-3 font-medium">
                AI recognition
              </span>
              <span class="reseller-shimmer inline-flex items-center rounded-full border border-base-300 bg-base-200/80 px-4 py-3 font-medium [animation-delay:0.4s]">
                Background removal
              </span>
              <span class="reseller-shimmer inline-flex items-center rounded-full border border-base-300 bg-base-200/80 px-4 py-3 font-medium [animation-delay:0.8s]">
                AR lifestyle photos
              </span>
              <span class="reseller-shimmer inline-flex items-center rounded-full border border-base-300 bg-base-200/80 px-4 py-3 font-medium [animation-delay:1.2s]">
                eBay · Depop · Poshmark · 9 more
              </span>
              <span class="reseller-shimmer inline-flex items-center rounded-full border border-base-300 bg-base-200/80 px-4 py-3 font-medium [animation-delay:1.6s]">
                Seller Storefront
              </span>
            </div>
          </div>

          <div class="relative mx-auto w-full max-w-xl">
            <div class="absolute inset-x-8 top-8 h-40 rounded-full bg-primary/18 blur-3xl"></div>

            <div class="relative grid gap-4">
              <div class="reseller-photo rotate-[-8deg] rounded-[2rem] border border-base-300/70 bg-base-100/95 p-4 shadow-[0_30px_80px_rgba(20,20,20,0.12)]">
                <img
                  src={~p"/images/#{@hero_pic}"}
                  class="aspect-[4/5] w-full rounded-[1.5rem] object-cover"
                />
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
                      Draft listing copy for the marketplaces you actually use without retyping the same story.
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
                      <p class="text-sm font-semibold">Mercari</p>
                      <p class="mt-2 text-xs text-neutral-content/70">
                        Short mobile-first copy + quick-sell details
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- STATS BAR --%>
      <div id="stats-bar" class="border-b border-base-300/60 bg-base-200/60">
        <div class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
          <div class="reveal-stagger grid grid-cols-2 gap-6 md:grid-cols-4">
            <div class="reveal text-center">
              <p id="stat-products" class="reseller-display text-4xl font-semibold text-primary">
                {@stat_products}+
              </p>
              <p class="mt-1 text-xs uppercase tracking-[0.28em] text-base-content/55">
                Products listed
              </p>
            </div>
            <div class="reveal text-center">
              <p id="stat-markets" class="reseller-display text-4xl font-semibold text-secondary">
                {@stat_markets} markets
              </p>
              <p class="mt-1 text-xs uppercase tracking-[0.28em] text-base-content/55">
                Supported platforms
              </p>
            </div>
            <div class="reveal text-center">
              <p id="stat-time" class="reseller-display text-4xl font-semibold text-accent">
                {@stat_time}%
              </p>
              <p class="mt-1 text-xs uppercase tracking-[0.28em] text-base-content/55">
                Less time per listing
              </p>
            </div>
            <div class="reveal text-center">
              <p id="stat-images" class="reseller-display text-4xl font-semibold text-warning">
                {@stat_images}s avg
              </p>
              <p class="mt-1 text-xs uppercase tracking-[0.28em] text-base-content/55">
                AI draft time
              </p>
            </div>
          </div>
        </div>
      </div>

      <%!-- WORKFLOW --%>
      <section id="workflow" class="border-b border-base-300/60 bg-base-200/45">
        <div class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8 lg:py-24">
          <div
            id="workflow-intro"
            class="reveal mx-auto max-w-3xl text-center"
          >
            <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">Workflow</p>
            <h2 class="reseller-display mt-4 text-4xl font-semibold tracking-[-0.03em] text-balance">
              From a pile of clothes to published listings — in under five minutes.
            </h2>
            <p class="mt-4 text-base leading-7 text-base-content/65">
              ResellerIO handles the full pipeline so you spend your time sourcing inventory, not retyping descriptions. Here's exactly what happens from the moment you pick up your phone.
            </p>
          </div>

          <div
            id="workflow-steps"
            class="mt-16 mx-auto max-w-4xl"
          >
            <%!-- Step 1 --%>
            <div class="reveal relative flex gap-6 pb-12 workflow-line">
              <div class="flex shrink-0 flex-col items-center">
                <div class="flex size-10 items-center justify-center rounded-full bg-primary text-primary-content text-sm font-bold shadow-lg">
                  1
                </div>
              </div>
              <div class="pb-2">
                <p class="text-xs font-semibold uppercase tracking-[0.3em] text-primary">Capture</p>
                <h3 class="mt-2 text-xl font-semibold">
                  Shoot or upload — raw and unedited is fine
                </h3>
                <p class="mt-3 leading-7 text-base-content/65">
                  Take photos straight from your phone or drag a folder of images into the browser. ResellerIO accepts any number of shots per item — front, back, tag, detail. Keep your originals untouched; we never overwrite them. The moment your last photo lands, background processing begins automatically.
                </p>
                <div class="mt-4 flex flex-wrap gap-2">
                  <span class="rounded-full bg-primary/10 px-3 py-1 text-xs font-medium text-primary">
                    Multi-photo upload
                  </span>
                  <span class="rounded-full bg-primary/10 px-3 py-1 text-xs font-medium text-primary">
                    Originals preserved
                  </span>
                  <span class="rounded-full bg-primary/10 px-3 py-1 text-xs font-medium text-primary">
                    Mobile-friendly
                  </span>
                </div>
              </div>
            </div>

            <%!-- Step 2 --%>
            <div class="reveal relative flex gap-6 pb-12 workflow-line" style="transition-delay:80ms">
              <div class="flex shrink-0 flex-col items-center">
                <div class="flex size-10 items-center justify-center rounded-full bg-secondary text-secondary-content text-sm font-bold shadow-lg">
                  2
                </div>
              </div>
              <div class="pb-2">
                <p class="text-xs font-semibold uppercase tracking-[0.3em] text-secondary">
                  AI Recognition
                </p>
                <h3 class="mt-2 text-xl font-semibold">
                  AI reads the item — brand, size, condition, and more
                </h3>
                <p class="mt-3 leading-7 text-base-content/65">
                  Our Gemini-powered vision layer scans every photo you uploaded. It identifies brand, category, sub-category, size, colour, material, condition, and notable details like hardware, stitching, or print type. The result is a structured product draft with confidence scores — no typing required.
                </p>
                <div class="mt-4 rounded-[1.25rem] border border-base-300/70 bg-base-100 p-4 text-sm">
                  <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
                    <div>
                      <p class="text-xs uppercase tracking-widest text-base-content/45">Brand</p>
                      <p class="mt-1 font-semibold">Levi's</p>
                    </div>
                    <div>
                      <p class="text-xs uppercase tracking-widest text-base-content/45">Size</p>
                      <p class="mt-1 font-semibold">W32 L30</p>
                    </div>
                    <div>
                      <p class="text-xs uppercase tracking-widest text-base-content/45">Condition</p>
                      <p class="mt-1 font-semibold">Very good</p>
                    </div>
                    <div>
                      <p class="text-xs uppercase tracking-widest text-base-content/45">Colour</p>
                      <p class="mt-1 font-semibold">Mid wash</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Step 3 --%>
            <div class="reveal relative flex gap-6 pb-12 workflow-line" style="transition-delay:160ms">
              <div class="flex shrink-0 flex-col items-center">
                <div class="flex size-10 items-center justify-center rounded-full bg-accent text-accent-content text-sm font-bold shadow-lg">
                  3
                </div>
              </div>
              <div class="pb-2">
                <p class="text-xs font-semibold uppercase tracking-[0.3em] text-accent">
                  Image Processing
                </p>
                <h3 class="mt-2 text-xl font-semibold">
                  Clean images, removed backgrounds, AR lifestyle shots
                </h3>
                <p class="mt-3 leading-7 text-base-content/65">
                  ResellerIO processes your photos in parallel. Backgrounds are stripped cleanly so items pop on any marketplace. If you want lifestyle context, the AI places your item in realistic settings — on a model, on a shelf, in a styled flat lay — without booking a shoot. All processed variants are stored alongside your originals.
                </p>
                <div class="mt-4 flex flex-wrap gap-2">
                  <span class="rounded-full bg-accent/10 px-3 py-1 text-xs font-medium text-accent">
                    Background removal
                  </span>
                  <span class="rounded-full bg-accent/10 px-3 py-1 text-xs font-medium text-accent">
                    Auto crop & straighten
                  </span>
                  <span class="rounded-full bg-accent/10 px-3 py-1 text-xs font-medium text-accent">
                    AR lifestyle generation
                  </span>
                </div>
              </div>
            </div>

            <%!-- Step 4 --%>
            <div class="reveal relative flex gap-6 pb-12 workflow-line" style="transition-delay:240ms">
              <div class="flex shrink-0 flex-col items-center">
                <div class="flex size-10 items-center justify-center rounded-full bg-warning text-warning-content text-sm font-bold shadow-lg">
                  4
                </div>
              </div>
              <div class="pb-2">
                <p class="text-xs font-semibold uppercase tracking-[0.3em] text-warning">
                  Price Research
                </p>
                <h3 class="mt-2 text-xl font-semibold">
                  AI hunts comparable sold listings to anchor your price
                </h3>
                <p class="mt-3 leading-7 text-base-content/65">
                  Before you set a price, ResellerIO queries real sold-listing data for items matching your product's brand, category, condition, and size. You get a suggested price range — low, mid, and high — based on what buyers have actually paid, not just what sellers are asking.
                </p>
                <div class="mt-4 rounded-[1.25rem] border border-base-300/70 bg-base-100 p-4">
                  <div class="flex items-center justify-between text-sm">
                    <span class="text-base-content/60">Suggested range</span>
                    <span class="font-semibold text-success">$38 – $65</span>
                  </div>
                  <div class="mt-3 h-2 w-full overflow-hidden rounded-full bg-base-300">
                    <div class="h-full w-[60%] rounded-full bg-success"></div>
                  </div>
                  <p class="mt-2 text-xs text-base-content/50">
                    Based on 24 comparable sold listings
                  </p>
                </div>
              </div>
            </div>

            <%!-- Step 5 --%>
            <div class="reveal relative flex gap-6 pb-12 workflow-line" style="transition-delay:320ms">
              <div class="flex shrink-0 flex-col items-center">
                <div class="flex size-10 items-center justify-center rounded-full bg-success text-success-content text-sm font-bold shadow-lg">
                  5
                </div>
              </div>
              <div class="pb-2">
                <p class="text-xs font-semibold uppercase tracking-[0.3em] text-success">
                  Listing Copy
                </p>
                <h3 class="mt-2 text-xl font-semibold">
                  Platform-perfect descriptions generated for each marketplace
                </h3>
                <p class="mt-3 leading-7 text-base-content/65">
                  With the product data and price signal in hand, the AI drafts separate listing copy for every marketplace you want to publish on. Each draft respects the tone, character limits, tag conventions, and buyer psychology of that specific platform — a punchy Depop caption looks nothing like a structured eBay title block.
                </p>
                <div class="mt-4 grid gap-3 sm:grid-cols-3">
                  <div class="rounded-[1rem] border border-base-300/60 bg-base-100 p-3">
                    <p class="text-xs font-semibold">eBay</p>
                    <p class="mt-1 text-xs text-base-content/55 leading-5">
                      "Levi's 501 Jeans W32 L30 — Mid Wash — Very Good Condition — Classic Straight Fit"
                    </p>
                  </div>
                  <div class="rounded-[1rem] border border-base-300/60 bg-base-100 p-3">
                    <p class="text-xs font-semibold">Depop</p>
                    <p class="mt-1 text-xs text-base-content/55 leading-5">
                      "iconic Levi's 501s 🤍 perfect mid wash, barely worn. fits true to size. no flaws 🔥 #levis #vintage"
                    </p>
                  </div>
                  <div class="rounded-[1rem] border border-base-300/60 bg-base-100 p-3">
                    <p class="text-xs font-semibold">Mercari</p>
                    <p class="mt-1 text-xs text-base-content/55 leading-5">
                      "Levi's 501 W32 — great condition, mid wash. Fast ship. Make an offer!"
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Step 6 --%>
            <div class="reveal relative flex gap-6" style="transition-delay:400ms">
              <div class="flex shrink-0 flex-col items-center">
                <div class="flex size-10 items-center justify-center rounded-full bg-primary text-primary-content text-sm font-bold shadow-lg">
                  6
                </div>
              </div>
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.3em] text-primary">
                  Review & Publish
                </p>
                <h3 class="mt-2 text-xl font-semibold">
                  You stay in control — review, edit, then push
                </h3>
                <p class="mt-3 leading-7 text-base-content/65">
                  Everything AI generates is a draft. The workspace surfaces confidence scores, flags uncertain fields, and lets you accept, override, or regenerate any section before it's marked ready. Once approved, the product lives in your inventory and your public Storefront — ready to copy-paste to any marketplace, or share as a direct link.
                </p>
                <div class="mt-4 flex flex-wrap gap-2">
                  <span class="rounded-full bg-primary/10 px-3 py-1 text-xs font-medium text-primary">
                    Confidence scores
                  </span>
                  <span class="rounded-full bg-primary/10 px-3 py-1 text-xs font-medium text-primary">
                    Field-level editing
                  </span>
                  <span class="rounded-full bg-primary/10 px-3 py-1 text-xs font-medium text-primary">
                    Storefront auto-publish
                  </span>
                  <span class="rounded-full bg-primary/10 px-3 py-1 text-xs font-medium text-primary">
                    Export to CSV / ZIP
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- FEATURES --%>
      <section id="features" class="border-b border-base-300/60 bg-base-100">
        <div class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8 lg:py-24">
          <div
            id="features-intro"
            class="reveal mx-auto max-w-3xl text-center"
          >
            <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
              Platform features
            </p>
            <h2 class="reseller-display mt-4 text-4xl font-semibold tracking-[-0.03em] text-balance">
              Everything a reseller needs — in one AI-powered platform.
            </h2>
            <p class="mt-4 text-base leading-7 text-base-content/65">
              From raw photos to published listings, ResellerIO handles the entire pipeline so you can focus on sourcing more inventory.
            </p>
          </div>

          <div
            id="features-grid"
            class="reveal-stagger mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-3"
          >
            <div class="feature-card reveal rounded-[2rem] border border-base-300/70 bg-base-200/50 p-7">
              <div class="flex size-12 items-center justify-center rounded-2xl bg-primary/12">
                <.icon name="hero-sparkles" class="size-6 text-primary" />
              </div>
              <h3 class="mt-5 text-lg font-semibold">AI Recognition & Metadata</h3>
              <p class="mt-2 text-sm leading-6 text-base-content/65">
                Instantly extract brand, category, condition, size, colour, and material from your photos. No manual typing — AI reads the item and builds a structured draft.
              </p>
            </div>

            <div class="feature-card reveal rounded-[2rem] border border-base-300/70 bg-base-200/50 p-7">
              <div class="flex size-12 items-center justify-center rounded-2xl bg-secondary/12">
                <.icon name="hero-photo" class="size-6 text-secondary" />
              </div>
              <h3 class="mt-5 text-lg font-semibold">Image Prep & Background Removal</h3>
              <p class="mt-2 text-sm leading-6 text-base-content/65">
                Automatically clean, crop, and straighten product photos. Remove messy backgrounds with one tap and get marketplace-ready images that convert.
              </p>
            </div>

            <div class="feature-card reveal rounded-[2rem] border border-base-300/70 bg-base-200/50 p-7">
              <div class="flex size-12 items-center justify-center rounded-2xl bg-accent/12">
                <.icon name="hero-cube-transparent" class="size-6 text-accent" />
              </div>
              <h3 class="mt-5 text-lg font-semibold">AR Lifestyle Photo Generation</h3>
              <p class="mt-2 text-sm leading-6 text-base-content/65">
                Generate real-life context shots without a photoshoot. Place your item in styled environments using AI — show buyers how it actually looks worn or used.
              </p>
            </div>

            <div class="feature-card reveal rounded-[2rem] border border-base-300/70 bg-base-200/50 p-7">
              <div class="flex size-12 items-center justify-center rounded-2xl bg-warning/15">
                <.icon name="hero-currency-dollar" class="size-6 text-warning" />
              </div>
              <h3 class="mt-5 text-lg font-semibold">AI Price Research</h3>
              <p class="mt-2 text-sm leading-6 text-base-content/65">
                Get data-backed pricing guidance for each item based on comparable sold listings. Price confidently and stop leaving money on the table.
              </p>
            </div>

            <div class="feature-card reveal rounded-[2rem] border border-base-300/70 bg-base-200/50 p-7">
              <div class="flex size-12 items-center justify-center rounded-2xl bg-success/12">
                <.icon name="hero-shopping-bag" class="size-6 text-success" />
              </div>
              <h3 class="mt-5 text-lg font-semibold">Marketplace-Specific Listings</h3>
              <p class="mt-2 text-sm leading-6 text-base-content/65">
                Generate tailored copy for every platform — eBay, Depop, Mercari, Vinted, Poshmark, Facebook Marketplace, and more. One product record, tuned for each channel's tone and rules.
              </p>
            </div>

            <div class="feature-card reveal rounded-[2rem] border border-base-300/70 bg-base-200/50 p-7">
              <div class="flex size-12 items-center justify-center rounded-2xl bg-primary/10">
                <.icon name="hero-building-storefront" class="size-6 text-primary" />
              </div>
              <h3 class="mt-5 text-lg font-semibold">Seller Storefront</h3>
              <p class="mt-2 text-sm leading-6 text-base-content/65">
                Your own branded storefront with custom theming, logo, header, searchable catalog, and shareable pages. Let buyers browse your full inventory directly — no marketplace cut.
              </p>
            </div>
          </div>
        </div>
      </section>

      <%!-- LIFESTYLE PHOTOS --%>
      <section id="lifestyle" class="border-b border-base-300/60 bg-base-100 overflow-hidden">
        <div class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8 lg:py-24">
          <div class="grid gap-12 lg:grid-cols-2 lg:items-center">
            <div id="lifestyle-intro" class="reveal-left">
              <p class="text-xs font-semibold uppercase tracking-[0.35em] text-accent">
                AI Lifestyle Photos
              </p>
              <h2 class="reseller-display mt-4 text-4xl font-semibold tracking-[-0.03em] text-balance">
                Your item. A real-life setting. Zero photoshoot.
              </h2>
              <p class="mt-4 text-base leading-7 text-base-content/65">
                Buyers don't just want to see a product on a white background — they want to imagine owning it. ResellerIO's AI takes your raw photo and generates realistic lifestyle scenes: a jacket on a model, sneakers styled on pavement, a bag on a café table.
              </p>
              <p class="mt-3 text-base leading-7 text-base-content/65">
                No studio. No model. No editing skills. Just your item — placed in a scene that sells.
              </p>
              <ul class="mt-6 space-y-3 text-sm text-base-content/70">
                <li class="flex items-start gap-3">
                  <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0 text-accent" />
                  Generated from your original photo — no reshooting needed
                </li>
                <li class="flex items-start gap-3">
                  <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0 text-accent" />
                  Multiple scene styles — urban, studio, lifestyle, editorial
                </li>
                <li class="flex items-start gap-3">
                  <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0 text-accent" />
                  Stored alongside originals — use on any marketplace
                </li>
                <li class="flex items-start gap-3">
                  <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0 text-accent" />
                  Listings with lifestyle photos sell faster and at higher prices
                </li>
              </ul>
            </div>

            <div id="lifestyle-grid" class="reveal-right">
              <div class="grid grid-cols-3 gap-3">
                <%= for img <- @storefront_imgs do %>
                  <div class="group relative overflow-hidden rounded-[1.5rem]">
                    <img
                      src={~p"/images/#{img}"}
                      class="aspect-square w-full object-cover transition-transform duration-500 group-hover:scale-105"
                    />
                    <div class="absolute inset-0 rounded-[1.5rem] bg-gradient-to-t from-black/40 to-transparent opacity-0 transition-opacity duration-300 group-hover:opacity-100">
                    </div>
                  </div>
                <% end %>
              </div>
              <div class="mt-4 flex items-center gap-3 rounded-[1.25rem] border border-accent/25 bg-accent/8 px-5 py-4">
                <.icon name="hero-sparkles" class="size-5 shrink-0 text-accent" />
                <p class="text-sm text-base-content/70">
                  <span class="font-semibold text-base-content">AI-generated in seconds</span>
                  — from your original upload, no extra steps required
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- MARKETPLACE STRIP --%>
      <section id="marketplace-strip" class="border-b border-base-300/60 bg-base-200/45">
        <div class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8 lg:py-20">
          <div class="grid gap-10 lg:grid-cols-[1fr_1.4fr] lg:items-center">
            <div id="marketplace-intro" class="reveal-left">
              <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
                Supported marketplaces
              </p>
              <h2 class="reseller-display mt-4 text-4xl font-semibold tracking-[-0.03em] text-balance">
                Write once, sell everywhere.
              </h2>
              <p class="mt-4 text-base leading-7 text-base-content/65">
                ResellerIO generates listing copy tuned to the voice, rules, and buyer expectations of every major resale platform. No more copy-pasting and manually rewriting for each channel.
              </p>
            </div>

            <div
              id="marketplace-grid"
              class="reveal-stagger reveal-right grid grid-cols-2 gap-4 sm:grid-cols-3"
            >
              <%= for {name, desc} <- [
                {"eBay", "Structured title + item specifics"},
                {"Depop", "Style-forward tone + hashtags"},
                {"Mercari", "Mobile-first, quick-sell copy"},
                {"Poshmark", "Shareable, aspirational tone"},
                {"Facebook Marketplace", "Local, plain-language copy"},
                {"OfferUp", "Casual + location-aware copy"},
                {"Whatnot", "Live-sell ready descriptions"},
                {"Grailed", "Streetwear & designer tone"},
                {"The RealReal", "Luxury authentication focus"},
                {"Vestiaire Collective", "European luxury tone"},
                {"thredUp", "Eco-conscious, value-first copy"},
                {"Etsy", "Handmade & vintage narrative"}
              ] do %>
                <div class="feature-card reveal rounded-[1.5rem] border border-base-300/70 bg-base-100 p-5">
                  <p class="font-semibold">{name}</p>
                  <p class="mt-2 text-xs text-base-content/60">{desc}</p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </section>

      <%!-- STOREFRONT SHOWCASE --%>
      <section id="storefront" class="border-b border-base-300/60 bg-base-100">
        <div class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8 lg:py-24">
          <div class="grid gap-10 lg:grid-cols-2 lg:items-center">
            <div id="storefront-intro" class="reveal-left">
              <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
                Seller Storefront
              </p>
              <h2 class="reseller-display mt-4 text-4xl font-semibold tracking-[-0.03em] text-balance">
                Your brand. Your store. Zero extra fees.
              </h2>
              <p class="mt-4 text-base leading-7 text-base-content/65">
                Every ResellerIO account comes with a fully brandable public storefront. Set your colours, upload a logo, write your story, and give buyers a clean browsing experience — on your terms.
              </p>
              <ul class="mt-6 space-y-3 text-sm text-base-content/70">
                <li class="flex items-start gap-3">
                  <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0 text-primary" />
                  Branded storefront URL at resellerio.com/store/you
                </li>
                <li class="flex items-start gap-3">
                  <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0 text-primary" />
                  Full-text search across your entire catalog
                </li>
                <li class="flex items-start gap-3">
                  <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0 text-primary" />
                  Custom pages, logo, header image, and colour theme
                </li>
                <li class="flex items-start gap-3">
                  <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0 text-primary" />
                  Share individual product links anywhere
                </li>
                <li class="flex items-start gap-3">
                  <.icon name="hero-check-circle" class="mt-0.5 size-5 shrink-0 text-primary" />
                  No marketplace cut — your buyers, your relationship
                </li>
              </ul>
            </div>

            <div id="storefront-mock" class="reveal-right">
              <div class="rounded-[2rem] border border-base-300/70 bg-neutral p-6 text-neutral-content shadow-[0_30px_80px_rgba(20,20,20,0.14)]">
                <div class="flex items-center gap-4">
                  <div class="flex size-14 items-center justify-center rounded-[1.25rem] bg-white/12">
                    <.icon name="hero-building-storefront" class="size-7 text-white/80" />
                  </div>
                  <div>
                    <p class="font-semibold">VintageLoot Store</p>
                    <p class="text-xs text-neutral-content/60">resellerio.com/store/vintageloot</p>
                  </div>
                </div>
                <div class="mt-6 grid grid-cols-3 gap-3">
                  <img
                    :for={img <- @storefront_imgs}
                    src={~p"/images/#{img}"}
                    class="aspect-square w-full rounded-[1rem] object-cover"
                  />
                </div>
                <div class="mt-5 flex items-center justify-between">
                  <p class="text-sm text-neutral-content/70">42 items · updated today</p>
                  <span class="rounded-full bg-primary px-4 py-1.5 text-xs font-semibold text-white">
                    Browse
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- FINAL CTA --%>
      <section id="cta" class="bg-base-100">
        <div class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8 lg:py-20">
          <div id="cta-block">
            <.surface
              tag="div"
              variant="ghost"
              padding="xl"
              class="reveal grid gap-8 rounded-[2.25rem] lg:grid-cols-[1fr_auto] lg:items-center"
            >
              <div>
                <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
                  Ready to start?
                </p>
                <h2
                  id="home-final-cta"
                  class="reseller-display mt-4 text-4xl font-semibold tracking-[-0.03em] text-balance"
                >
                  ResellerIO — AI Inventory for Resellers. List faster. Earn more.
                </h2>
                <p class="mt-4 max-w-2xl text-base leading-7 text-base-content/70">
                  Join resellers already using ResellerIO to cut listing time, nail pricing, and sell across every major marketplace — all from one calm workspace.
                </p>
              </div>

              <div class="flex flex-col gap-3 sm:flex-row lg:flex-col">
                <%= if @current_user do %>
                  <.link navigate={~p"/app"} class="btn btn-primary rounded-full px-7">
                    Open workspace
                  </.link>
                <% else %>
                  <.link navigate={~p"/sign-up"} class="btn btn-primary rounded-full px-7">
                    Create free account
                  </.link>
                <% end %>
                <a href="#home-hero" class="btn btn-ghost rounded-full px-7">Back to top</a>
              </div>
            </.surface>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
