# ResellerIO Pricing Implementation Plan

Payment and subscription infrastructure using LemonSqueezy.

## Delivery Status

| Step | Scope | Status |
|---|---|---|
| PR-1 | Pricing page LiveView (`/pricing`) | ✅ |
| PR-2 | User schema subscription fields + `Billing.Plans` + `Billing` context | ✅ |
| PR-3 | LemonSqueezy webhook handler + event processing | ✅ |
| PR-4 | Expiration email templates + `SubscriptionExpiryReminderWorker` | ✅ |
| PR-5 | Checkout URL generation + post-checkout UX + `/app/settings` subscription section | ✅ |
| PR-6 | Monthly usage aggregation + `check_plan_limit/1` + 402 limit-exceeded UX | ✅ |
| PR-7 | Tests, admin tooling, config hardening | ✅ |

## Key Modules

- `Reseller.Billing` — subscription state management
- `Reseller.Billing.Plans` — plan limits, `limits_for_user/1`, `all/0`, `plan_info/1`
- `Reseller.Billing.WebhookHandler` — LemonSqueezy event dispatch
- `Reseller.Billing.LemonSqueezy` — checkout URL building
- `Reseller.Billing.Emails` — lifecycle email templates
- `Reseller.Workers.ExpiryScheduler` — daily GenServer that fires `SubscriptionExpiryReminderWorker`
- `Reseller.Workers.SubscriptionExpiryReminderWorker` — 7d/2d reminder + expiry sweeps
- `ResellerWeb.Webhooks.LemonSqueezyController` — HMAC-verified webhook entry point
- `ResellerWeb.PricingLive` — public `/pricing` page

## Known Gaps

See `docs/PRICING_CHECKS.md` for full audit. Critical items:

- T1/A4: Trial not started on registration (web + API `register_user`)
- T3: `users_past_expiry/0` excludes trialing users
- L1/A2: `generate_lifestyle_images` has no `check_plan_limit` call
- A1: `GET /api/v1/me` does not expose plan/subscription fields

## Open Questions

1. Free plan vs. trial-only — permanent free tier with low limits, or time-limited trial only?
2. In-app billing (iOS/Android) via App Store / Play Store alongside LemonSqueezy web billing.
3. Annual billing launch timing — monthly first, add annual once churn data exists.
4. LemonSqueezy webhook deduplication — append `webhook_log` table to prevent double-credit on replayed `order_created` events.
5. Paused subscriptions — LemonSqueezy supports subscription pausing; add `plan_status: "paused"` if needed.
