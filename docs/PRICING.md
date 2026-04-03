# Pricing

This file summarizes the pricing model implemented in the current code and `/pricing` LiveView.

## Plans

Code-backed plan limits from `Reseller.Billing.Plans`:

| Plan | Monthly Price | AI Drafts | Background Removals | Lifestyle Images | Price Research |
| --- | --- | --- | --- | --- | --- |
| `free` | `$0` | 5 | 15 | 0 | 5 |
| `starter` | `$19` | 50 | 150 | 150 | 50 |
| `growth` | `$39` | 250 | 750 | 750 | 250 |
| `pro` | `$79` | 1000 | 3000 | 3000 | 1000 |

The public pricing page markets only the paid plans. The `free` plan exists in billing/limits code.

## Annual Pricing Shown in UI

`ResellerWeb.PricingLive` presents:

| Plan | Annual Equivalent | Annual Total |
| --- | --- | --- |
| Starter | `$15/mo` | `$190/yr` |
| Growth | `$33/mo` | `$390/yr` |
| Pro | `$66/mo` | `$790/yr` |

## Add-ons Shown in UI

| Add-on | Price | Effect |
| --- | --- | --- |
| AI Draft Pack | `$8` | `+100 AI drafts` |
| Lifestyle Image Pack | `$10` | `+50 lifestyle generations` |
| Background Removal Pack | `$7` | `+100 background removals` |
| Extra Seat | `$14` | `+1 seat` |

Add-on balances are stored in `users.addon_credits`.

## Billing Model

Current billing integration:

- hosted checkout via LemonSqueezy
- webhook-driven subscription updates
- expiry reminder worker
- plan limits enforced through `Reseller.Metrics`

Key modules:

- `Reseller.Billing`
- `Reseller.Billing.Plans`
- `Reseller.Billing.LemonSqueezy`
- `Reseller.Billing.WebhookHandler`
- `Reseller.Workers.ExpiryScheduler`
- `Reseller.Workers.SubscriptionExpiryReminderWorker`

## Enforcement

Daily API ceilings:

- free users are gated through `Reseller.Metrics.check_limit/1`

Monthly plan ceilings:

- paid users are gated through `Reseller.Metrics.check_plan_limit/1`
- processing endpoints use `Reseller.Metrics.check_processing_limit/1`

Usage bucket mapping:

- AI drafts: Gemini recognition/description/reconciliation + marketplace listing generation
- background removals: Photoroom
- lifestyle images: Gemini lifestyle image generation
- price research: Gemini + SerpApi

## Product Positioning

The current app is priced as an AI-heavy seller workflow, not a lightweight crosslister. The differentiated features in code are:

- AI recognition and structured metadata
- price research
- marketplace-specific copy generation
- background removal
- optional lifestyle image generation
- seller storefront
- ZIP export/import
- full API access

## Source of Truth

- limits: `lib/reseller/billing/plans.ex`
- checkout page copy: `lib/reseller_web/live/pricing_live.ex`
- enforcement: `lib/reseller/metrics.ex`
