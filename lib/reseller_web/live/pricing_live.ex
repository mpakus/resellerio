defmodule ResellerWeb.PricingLive do
  use ResellerWeb, :live_view

  @plans [
    %{
      key: "starter",
      name: "Starter",
      tagline: "For casual and part-time sellers.",
      monthly: 19,
      annual: 15,
      annual_total: 190,
      popular: false,
      cta: "Start free trial",
      color: "secondary",
      limits: %{
        ai_drafts: 50,
        bg_removals: 150,
        lifestyle: 150,
        price_research: 50
      },
      features: [
        "50 AI product drafts / month",
        "150 background removals / month",
        "150 lifestyle image generations / month",
        "50 price research runs / month",
        "Marketplace listing copy (all 12 channels)",
        "1 seller storefront (full branding)",
        "Unlimited inventory & originals stored",
        "ZIP export & import",
        "API access",
        "Email & support system"
      ]
    },
    %{
      key: "growth",
      name: "Growth",
      tagline: "The recommended plan for active resellers.",
      monthly: 39,
      annual: 33,
      annual_total: 390,
      popular: true,
      cta: "Start free trial",
      color: "primary",
      limits: %{
        ai_drafts: 250,
        bg_removals: 750,
        lifestyle: 750,
        price_research: 250
      },
      features: [
        "250 AI product drafts / month",
        "750 background removals / month",
        "750 lifestyle image generations / month",
        "250 price research runs / month",
        "Marketplace listing copy (all 12 channels)",
        "1 seller storefront (full branding)",
        "Unlimited inventory & originals stored",
        "ZIP export & import",
        "API access",
        "Priority email & support system"
      ]
    },
    %{
      key: "pro",
      name: "Pro",
      tagline: "For serious solo resellers and small teams.",
      monthly: 79,
      annual: 66,
      annual_total: 790,
      popular: false,
      cta: "Start free trial",
      color: "accent",
      limits: %{
        ai_drafts: 1000,
        bg_removals: 3000,
        lifestyle: 3000,
        price_research: 1000
      },
      features: [
        "1,000 AI product drafts / month",
        "3,000 background removals / month",
        "3,000 lifestyle image generations / month",
        "1,000 price research runs / month",
        "Marketplace listing copy (all 12 channels)",
        "1 seller storefront (full branding)",
        "Unlimited inventory & originals stored",
        "ZIP export & import",
        "API access",
        "2 seats included",
        "Priority email & support system"
      ]
    }
  ]

  @addons [
    %{
      key: "ai_draft_pack",
      name: "AI Draft Pack",
      price: 8,
      credits: "+100 AI product drafts",
      icon: "hero-sparkles",
      color: "primary"
    },
    %{
      key: "lifestyle_pack",
      name: "Lifestyle Image Pack",
      price: 10,
      credits: "+50 lifestyle image generations",
      icon: "hero-cube-transparent",
      color: "accent"
    },
    %{
      key: "bg_removal_pack",
      name: "Background Removal Pack",
      price: 7,
      credits: "+100 background removals",
      icon: "hero-photo",
      color: "secondary"
    },
    %{
      key: "extra_seat",
      name: "Extra Seat",
      price: 14,
      credits: "+1 additional workspace seat",
      icon: "hero-user-plus",
      color: "warning"
    }
  ]

  @faqs [
    %{
      q: "Is there a free trial?",
      a:
        "Yes — 7 days free, no credit card required. Your products and data are preserved if you don't subscribe after the trial."
    },
    %{
      q: "Can I cancel anytime?",
      a:
        "Absolutely. Cancel from your account settings at any time. Your access continues until the end of the current billing period and all your data is preserved."
    },
    %{
      q: "What happens when I hit my monthly limit?",
      a:
        "AI processing for that operation is paused until your next billing cycle resets. You can also grab a one-time credit pack to keep going without upgrading."
    },
    %{
      q: "Do add-on credits expire?",
      a: "No. Add-on credits roll over indefinitely — they don't reset with your billing cycle."
    },
    %{
      q: "Can I use the mobile app on any plan?",
      a:
        "Yes. All plans include full API access, so the iOS and Android apps work on every paid tier."
    },
    %{
      q: "Can I switch plans later?",
      a:
        "Yes. You can upgrade or downgrade at any time. Upgrades take effect immediately; downgrades apply at the next billing cycle."
    },
    %{
      q: "What if I need more than Pro?",
      a: "Contact us at hello@resellerio.com and we'll work out a custom arrangement."
    }
  ]

  @comparison_rows [
    %{label: "AI product drafts / month", starter: "50", growth: "250", pro: "1,000"},
    %{label: "Background removals / month", starter: "150", growth: "750", pro: "3,000"},
    %{label: "Lifestyle image generations / month", starter: "150", growth: "750", pro: "3,000"},
    %{label: "Price research runs / month", starter: "50", growth: "250", pro: "1,000"},
    %{
      label: "Marketplace listing copy (12 channels)",
      starter: :check,
      growth: :check,
      pro: :check
    },
    %{
      label: "Seller storefront",
      starter: "Full branding",
      growth: "Full branding",
      pro: "Full branding"
    },
    %{
      label: "Inventory & originals storage",
      starter: "Unlimited",
      growth: "Unlimited",
      pro: "Unlimited"
    },
    %{label: "ZIP export & import", starter: :check, growth: :check, pro: :check},
    %{label: "API access (mobile app)", starter: :check, growth: :check, pro: :check},
    %{label: "Seats", starter: "1", growth: "1", pro: "2"},
    %{
      label: "Support",
      starter: "Email & support system",
      growth: "Priority line",
      pro: "Priority line"
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: ResellerWeb.PageTitle.build("Pricing", "Plans"),
       current_scope: nil,
       billing: :monthly,
       open_faqs: MapSet.new(),
       plans: @plans,
       addons: @addons,
       faqs: @faqs,
       comparison_rows: @comparison_rows
     )}
  end

  @impl true
  def handle_event("set_billing", %{"period" => period}, socket) do
    billing = if period == "annual", do: :annual, else: :monthly
    {:noreply, assign(socket, billing: billing)}
  end

  @impl true
  def handle_event("toggle_faq", %{"idx" => idx}, socket) do
    open = socket.assigns.open_faqs
    idx = String.to_integer(idx)
    open = if MapSet.member?(open, idx), do: MapSet.delete(open, idx), else: MapSet.put(open, idx)
    {:noreply, assign(socket, open_faqs: open)}
  end

  @impl true
  def handle_event("choose_plan", %{"plan" => plan}, socket) do
    user = socket.assigns.current_user

    if is_nil(user) do
      {:noreply, push_navigate(socket, to: ~p"/sign-up")}
    else
      period = socket.assigns.billing

      case Reseller.Billing.LemonSqueezy.checkout_url(plan, period, user) do
        {:ok, url} ->
          {:noreply, redirect(socket, external: url)}

        {:error, :variant_not_configured} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Checkout is not configured yet. Please contact us at hello@resellerio.com."
           )}

        {:error, _reason} ->
          {:noreply,
           put_flash(socket, :error, "Something went wrong. Please try again or contact support.")}
      end
    end
  end

  defp plan_price(plan, :monthly), do: plan.monthly
  defp plan_price(plan, :annual), do: plan.annual

  defp plan_cta(_plan, nil), do: "Start free trial"

  defp plan_cta(plan, user) do
    cond do
      user.plan == plan.key -> "Current plan"
      user.plan in ["growth", "pro"] and plan.key == "starter" -> "Downgrade"
      true -> "Upgrade to #{plan.name}"
    end
  end

  defp faq_open?(open_faqs, idx), do: MapSet.member?(open_faqs, idx)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <%!-- HEADER --%>
      <section class="border-b border-base-300/60 bg-base-100">
        <div class="mx-auto max-w-4xl px-4 py-16 text-center sm:px-6 lg:px-8">
          <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">Pricing</p>
          <h1 class="reseller-display mt-4 text-5xl font-semibold tracking-[-0.04em] text-balance">
            Simple, transparent pricing<br />for serious resellers.
          </h1>
          <p class="mx-auto mt-5 max-w-2xl text-lg leading-7 text-base-content/65">
            Start with a 7-day free trial — no card required. Pick the plan that fits your volume and scale up anytime.
          </p>

          <%!-- Billing toggle --%>
          <div class="mt-8 inline-flex items-center gap-1 rounded-full border border-base-300/70 bg-base-200/60 p-1">
            <button
              phx-click="set_billing"
              phx-value-period="monthly"
              class={[
                "rounded-full px-5 py-2 text-sm font-medium transition-all",
                if(@billing == :monthly,
                  do: "bg-base-100 shadow text-base-content",
                  else: "text-base-content/60 hover:text-base-content"
                )
              ]}
            >
              Monthly
            </button>
            <button
              phx-click="set_billing"
              phx-value-period="annual"
              class={[
                "rounded-full px-5 py-2 text-sm font-medium transition-all flex items-center gap-2",
                if(@billing == :annual,
                  do: "bg-base-100 shadow text-base-content",
                  else: "text-base-content/60 hover:text-base-content"
                )
              ]}
            >
              Annual
              <span class="rounded-full bg-success/15 px-2 py-0.5 text-xs font-semibold text-success">
                Save ~17%
              </span>
            </button>
          </div>
        </div>
      </section>

      <%!-- PLAN CARDS --%>
      <section class="border-b border-base-300/60 bg-base-200/40">
        <div class="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
          <div class="grid gap-6 lg:grid-cols-3">
            <div
              :for={plan <- @plans}
              class={[
                "relative flex flex-col rounded-[2rem] border bg-base-100 p-8",
                if(plan.popular,
                  do: "border-primary shadow-[0_0_0_1px_oklch(var(--p))] shadow-primary/20",
                  else: "border-base-300/70"
                )
              ]}
            >
              <div
                :if={plan.popular}
                class="absolute -top-3.5 left-1/2 -translate-x-1/2 rounded-full bg-primary px-4 py-1 text-xs font-semibold text-primary-content shadow"
              >
                Most popular
              </div>

              <div>
                <p class={["text-sm font-semibold uppercase tracking-[0.3em]", "text-#{plan.color}"]}>
                  {plan.name}
                </p>
                <p class="mt-2 text-sm text-base-content/60">{plan.tagline}</p>

                <div class="mt-6 flex items-end gap-1">
                  <span class="reseller-display text-5xl font-semibold tracking-tight">
                    ${plan_price(plan, @billing)}
                  </span>
                  <span class="mb-1.5 text-base-content/55">/mo</span>
                </div>
                <p :if={@billing == :annual} class="mt-1 text-xs text-base-content/50">
                  Billed annually · ${plan.annual_total}/yr
                </p>
                <p :if={@billing == :monthly} class="mt-1 text-xs text-base-content/50">
                  Billed monthly · cancel anytime
                </p>

                <button
                  phx-click="choose_plan"
                  phx-value-plan={plan.key}
                  class={[
                    "btn btn-sm mt-6 w-full rounded-full",
                    if(plan.popular, do: "btn-primary", else: "btn-outline")
                  ]}
                >
                  {plan_cta(plan, @current_user)}
                </button>
              </div>

              <div class="mt-8 border-t border-base-300/60 pt-6">
                <ul class="space-y-3">
                  <li :for={feature <- plan.features} class="flex items-start gap-3 text-sm">
                    <.icon
                      name="hero-check-circle"
                      class={"mt-0.5 size-4 shrink-0 text-#{plan.color}"}
                    />
                    <span class="text-base-content/75">{feature}</span>
                  </li>
                </ul>
              </div>
            </div>
          </div>

          <p class="mt-6 text-center text-xs text-base-content/45">
            All plans include a 7-day free trial. No credit card required to start.
          </p>
        </div>
      </section>

      <%!-- COMPARISON TABLE --%>
      <section class="border-b border-base-300/60 bg-base-100">
        <div class="mx-auto max-w-5xl px-4 py-16 sm:px-6 lg:px-8">
          <div class="text-center">
            <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
              Compare plans
            </p>
            <h2 class="reseller-display mt-4 text-3xl font-semibold tracking-[-0.03em]">
              Everything in one place
            </h2>
          </div>

          <div class="mt-10 overflow-hidden rounded-[1.5rem] border border-base-300/70">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-base-300/60 bg-base-200/60">
                  <th class="px-5 py-4 text-left font-semibold text-base-content/70">Feature</th>
                  <th class="px-5 py-4 text-center font-semibold text-secondary">Starter</th>
                  <th class="px-5 py-4 text-center font-semibold text-primary">Growth</th>
                  <th class="px-5 py-4 text-center font-semibold text-accent">Pro</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-base-300/50">
                <tr :for={row <- @comparison_rows} class="hover:bg-base-200/30 transition-colors">
                  <td class="px-5 py-3.5 text-base-content/70">{row.label}</td>
                  <td class="px-5 py-3.5 text-center">
                    <.comparison_cell value={row.starter} />
                  </td>
                  <td class="px-5 py-3.5 text-center">
                    <.comparison_cell value={row.growth} />
                  </td>
                  <td class="px-5 py-3.5 text-center">
                    <.comparison_cell value={row.pro} />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>

      <%!-- ADD-ON PACKS --%>
      <section class="border-b border-base-300/60 bg-base-200/40">
        <div class="mx-auto max-w-5xl px-4 py-16 sm:px-6 lg:px-8">
          <div class="text-center">
            <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">Add-ons</p>
            <h2 class="reseller-display mt-4 text-3xl font-semibold tracking-[-0.03em]">
              Need more? Grab a credit pack.
            </h2>
            <p class="mx-auto mt-3 max-w-xl text-base text-base-content/60">
              One-time purchases that roll over indefinitely — no expiry, no subscription required.
            </p>
          </div>

          <div class="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div
              :for={addon <- @addons}
              class="flex flex-col rounded-[1.75rem] border border-base-300/70 bg-base-100 p-6"
            >
              <div class={[
                "flex size-11 items-center justify-center rounded-2xl",
                "bg-#{addon.color}/10"
              ]}>
                <.icon name={addon.icon} class={"size-5 text-#{addon.color}"} />
              </div>
              <p class="mt-4 font-semibold">{addon.name}</p>
              <p class="mt-1 text-sm text-base-content/60">{addon.credits}</p>
              <div class="mt-auto pt-5">
                <p class="reseller-display text-3xl font-semibold">${addon.price}</p>
                <p class="text-xs text-base-content/45">one-time</p>
                <.link
                  navigate={~p"/sign-up"}
                  class="btn btn-outline btn-sm mt-4 w-full rounded-full"
                >
                  Buy pack
                </.link>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- FAQ --%>
      <section class="border-b border-base-300/60 bg-base-100">
        <div class="mx-auto max-w-3xl px-4 py-16 sm:px-6 lg:px-8">
          <div class="text-center">
            <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
              Questions
            </p>
            <h2 class="reseller-display mt-4 text-3xl font-semibold tracking-[-0.03em]">
              Frequently asked
            </h2>
          </div>

          <div class="mt-10 divide-y divide-base-300/60">
            <div
              :for={{faq, idx} <- Enum.with_index(@faqs)}
              class="cursor-pointer py-5"
              phx-click="toggle_faq"
              phx-value-idx={idx}
            >
              <div class="flex items-center justify-between gap-4">
                <p class="font-medium">{faq.q}</p>
                <.icon
                  name={
                    if faq_open?(@open_faqs, idx), do: "hero-chevron-up", else: "hero-chevron-down"
                  }
                  class="size-4 shrink-0 text-base-content/40"
                />
              </div>
              <p
                :if={faq_open?(@open_faqs, idx)}
                class="mt-3 text-sm leading-6 text-base-content/65"
              >
                {faq.a}
              </p>
            </div>
          </div>
        </div>
      </section>

      <%!-- FINAL CTA --%>
      <section class="bg-base-100">
        <div class="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8 lg:py-20">
          <.surface
            tag="div"
            variant="ghost"
            padding="xl"
            class="grid gap-8 rounded-[2.25rem] lg:grid-cols-[1fr_auto] lg:items-center"
          >
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
                Ready to start?
              </p>
              <h2 class="reseller-display mt-4 text-4xl font-semibold tracking-[-0.03em] text-balance">
                7-day free trial. No card required.
              </h2>
              <p class="mt-4 max-w-2xl text-base leading-7 text-base-content/70">
                Join resellers already using ResellerIO to cut listing time, nail pricing, and sell across every major marketplace — all from one AI-powered workspace.
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
              <a href="#" class="btn btn-ghost rounded-full px-7">Back to top</a>
            </div>
          </.surface>
        </div>
      </section>
    </Layouts.app>
    """
  end

  attr :value, :any, required: true

  defp comparison_cell(%{value: :check} = assigns) do
    ~H"""
    <.icon name="hero-check-circle" class="mx-auto size-5 text-success" />
    """
  end

  defp comparison_cell(assigns) do
    ~H"""
    <span class="text-base-content/70">{@value}</span>
    """
  end
end
