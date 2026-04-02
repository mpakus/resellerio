# ResellerIO Pricing

## Positioning

ResellerIO is an **AI-first reseller workflow platform** — not a bargain crosslisting tool.

Core capabilities justifying premium positioning:
- AI item recognition and structured metadata extraction (Gemini)
- Background removal and image cleanup (Photoroom)
- AI lifestyle photo generation (Gemini + Photoroom)
- AI price research from real comparable sold listings (SerpApi + Gemini)
- Marketplace-specific listing copy for 12 channels
- Seller storefront with custom branding

That positions us against mid-market tools (Vendoo, List Perfectly, Crosslist at $29–$69/mo)
while offering capabilities none of them have (AI drafting, lifestyle generation, price research).

---

## Competitor Snapshot

| Tool | Price Range | Key Gap vs. ResellerIO |
|---|---|---|
| Flyp | ~$0 (fee-based) | No AI drafting, no lifestyle photos |
| Vendoo | $14–$49/mo | No AI enrichment, no image gen |
| List Perfectly | $29–$69/mo | No image gen, no price research |
| Crosslist | $19–$49/mo | No AI metadata, no storefront |

ResellerIO is the only tool in the category combining **intake + AI enrichment + image prep + pricing + listing generation + storefront** in one workflow.

---

## Plans

### Free Trial
- 7 days full access, no card required
- After trial: account locked until plan selected (products and data preserved)
- Alternative entry: 25 free AI drafts without a card (better for acquisition)

---

### Starter — $19/month

For casual or part-time sellers getting started.

| Feature | Limit |
|---|---|
| AI product drafts (recognition + metadata) | 50 / month |
| Background removals (Photoroom) | 150 / month |
| AI lifestyle image generations | 150 / month |
| Price research runs | 50 / month |
| Marketplace listing copies generated | included |
| Storefront | 1 (full branding) |
| Product inventory stored | unlimited |
| Image originals stored | unlimited |
| ZIP export/import | included |
| API access | included |
| Support | Email & support system |

**Daily API cost ceiling (enforced):** ~$0.50 / day

---

### Growth — $39/month ⭐ Most popular

The recommended default plan for active resellers.

| Feature | Limit |
|---|---|
| AI product drafts | 250 / month |
| Background removals | 750 / month |
| AI lifestyle image generations | 750 / month |
| Price research runs | 250 / month |
| Marketplace listing copies | included |
| Storefront | 1 (full branding) |
| Product inventory stored | unlimited |
| Image originals stored | unlimited |
| ZIP export/import | included |
| API access | included |
| Support | Priority email & support system |

**Daily API cost ceiling (enforced):** ~$2.00 / day

---

### Pro — $79/month

For serious solo resellers and small teams.

| Feature | Limit |
|---|---|
| AI product drafts | 1,000 / month |
| Background removals | 3,000 / month |
| AI lifestyle image generations | 3,000 / month |
| Price research runs | 1,000 / month |
| Marketplace listing copies | included |
| Storefront | 1 (full branding) |
| Product inventory stored | unlimited |
| Image originals stored | unlimited |
| ZIP export/import | included |
| API access | included |
| Seats | 2 included |
| Support | Priority email & support system |

**Daily API cost ceiling (enforced):** ~$5.00 / day

---

## Add-on Packs (one-time purchases)

Add-ons are processed via LemonSqueezy one-time payments and credited immediately to the account.

| Add-on | Price | Credits |
|---|---|---|
| AI Draft Pack | $8 | +100 AI product drafts |
| Lifestyle Image Pack | $10 | +50 lifestyle image generations |
| Background Removal Pack | $7 | +100 background removals |
| Extra Seat | $14/mo | +1 additional workspace seat |

Add-on credits roll over month-to-month (they do not expire with the billing cycle).

---

## Annual Billing

Annual plans offer ~2 months free:

| Plan | Monthly | Annual (÷12) | Savings |
|---|---|---|---|
| Starter | $19/mo | $15.83/mo ($190/yr) | ~17% |
| Growth | $39/mo | $32.50/mo ($390/yr) | ~17% |
| Pro | $79/mo | $65.83/mo ($790/yr) | ~17% |

Launch with monthly only. Add annual billing as a growth lever once monthly retention is established.

---

## Limit-to-Metric Mapping

Plan limits map directly to existing `Reseller.Metrics` infrastructure:

| Plan Limit | Metric Field | Provider |
|---|---|---|
| AI product drafts | `gemini_calls` (operation: recognition, description) | Gemini |
| Background removals | `photoroom_calls` | Photoroom |
| Lifestyle image generations | `gemini_calls` (operation: lifestyle_image) | Gemini + Photoroom |
| Price research runs | `serp_api_calls` + `gemini_calls` (operation: price_research_*) | SerpApi + Gemini |

Monthly limits are checked against `api_usage_events` aggregated by `user_id` and month.
Daily hard ceilings map to the existing `daily_limits` config in `Reseller.Metrics`.

Plan-level monthly limits will require a new `user_plan_limits` lookup in `check_limit/2`.

---

## Mobile / App Store Consideration

Because ResellerIO targets iOS and Android:
- Keep the same plan names across web and mobile
- Web billing (LemonSqueezy) is the canonical source of truth
- Leave margin headroom for App Store (30%) and Play Store (15–30%) fees if in-app billing is added later
- Do not set pricing so low it becomes unprofitable on mobile

---

## What to Avoid at Launch

- **$9/mo all-in** — unsustainable with Gemini + Photoroom + SerpApi costs
- **Starting at $69+** — too expensive for a new brand without established trust
- **More than 3 paid plans** — adds decision paralysis
- **Charging for stored inventory** — sellers hate paying for unsold items
- **Treating AI as a minor add-on** — AI is the core product differentiator

---

## LemonSqueezy Integration

### Subscriptions
Use [LemonSqueezy Subscriptions](https://www.lemonsqueezy.com/ecommerce/subscriptions) for recurring plan billing.

Key flows:
1. User selects plan on `/pricing` → redirected to hosted LemonSqueezy checkout
2. On successful payment: webhook → update `users.plan` + `users.plan_expires_at`
3. On renewal: webhook → extend `plan_expires_at`
4. On cancellation: webhook → set `plan_status = "canceling"`, access continues until `plan_expires_at`
5. On expiry: access gated to free-tier limits

### One-time Payments
Use [LemonSqueezy Payments](https://www.lemonsqueezy.com/ecommerce/payments) for add-on credit packs.

Key flows:
1. User clicks add-on → LemonSqueezy checkout for one-time payment
2. On successful payment: webhook → credit `users.addon_credits` map
3. Credits consumed from addon bucket before monthly plan bucket

### Webhook Events to Handle
| Event | Action |
|---|---|
| `subscription_created` | Assign plan, set `plan_expires_at`, send welcome email |
| `subscription_updated` | Update plan tier or status |
| `subscription_renewed` | Extend `plan_expires_at`, send renewal confirmation |
| `subscription_cancelled` | Set `plan_status = "canceling"` |
| `subscription_expired` | Downgrade to free/locked, send expiry email |
| `subscription_payment_failed` | Send payment failure email, set `plan_status = "past_due"` |
| `order_created` (add-on) | Credit addon pack to user account |

### Expiration Email Cadence
- **7 days before** expiry: "Your ResellerIO plan expires in 7 days" — include renewal CTA
- **2 days before** expiry: "Last chance — your plan expires in 2 days" — urgent CTA
- **On expiry**: "Your ResellerIO plan has expired" — offer to reactivate, data preserved
- **After payment failure**: "Action required — update your billing information"

---

## Pricing Page Sections

The public `/pricing` page should include:

1. **Header** — "Simple, transparent pricing for serious resellers."
2. **Billing toggle** — Monthly / Annual (annual shows savings badge)
3. **Plan cards** — Starter / Growth / Pro with feature comparison
4. **Add-on section** — "Need more? Grab a credit pack."
5. **FAQ** — Common questions about trials, cancellation, data, mobile
6. **Final CTA** — "Start your 7-day free trial. No card required."

### FAQ Content
- *Can I cancel anytime?* — Yes. Your data is preserved. You can reactivate at any time.
- *What happens when I hit my limit?* — Processing is paused for that operation until the next billing cycle or you buy a pack.
- *Do add-on credits expire?* — No. Add-on credits roll over indefinitely.
- *Is there a free trial?* — 7 days free, no card required.
- *Can I use the mobile app on any plan?* — Yes, all plans include API access for mobile.
- *What if I need more than Pro?* — Contact us for a custom arrangement.
