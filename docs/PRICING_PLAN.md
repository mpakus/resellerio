# Pricing Implementation Status

Current billing implementation is largely shipped.

## Shipped

- public pricing page at `/pricing`
- plan metadata in `Reseller.Billing.Plans`
- subscription state on `users`
- LemonSqueezy webhook ingestion
- checkout URL generation
- reminder and expiry workers
- monthly usage endpoint at `GET /api/v1/me/usage`
- limit-exceeded API responses with upgrade URL

## Key Modules

- `Reseller.Billing`
- `Reseller.Billing.Plans`
- `Reseller.Billing.LemonSqueezy`
- `Reseller.Billing.WebhookHandler`
- `Reseller.Billing.Emails`
- `Reseller.Workers.ExpiryScheduler`
- `Reseller.Workers.SubscriptionExpiryReminderWorker`
- `ResellerWeb.PricingLive`

## Remaining Product Decisions

- whether the free plan is a permanent tier or only a trial/fallback state
- whether in-app billing will coexist with LemonSqueezy web billing
- whether annual billing should remain UI-visible before full go-to-market rollout
- whether extra seats should become an actual enforced seat model instead of a billing-only concept
