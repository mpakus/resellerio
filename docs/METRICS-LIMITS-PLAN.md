# Metrics and Limits

This is the compressed status doc for the metrics and limit system.

## What Exists

Recorded event model:

- `api_usage_events`

Daily summary model:

- `user_usage_summaries`

Primary capabilities in `Reseller.Metrics`:

- append-only event recording
- best-effort `record_event_safe/1`
- per-user and per-product aggregation
- platform totals and top-cost reports
- monthly usage rollups by product operation bucket
- daily hard-limit checks
- monthly plan-limit checks

## Providers Tracked

- Gemini
- SerpApi
- Photoroom

## Operation Buckets Used for Plan Limits

- `ai_drafts`
- `background_removals`
- `lifestyle`
- `price_research`

## Where Limits Apply

API/product processing endpoints call `Metrics.check_processing_limit/1`.

Current logic:

- `plan in [nil, "free"]` -> use daily hard ceilings
- paid plans -> use monthly plan limits plus add-on credits

## Current Admin Query Surface

`Reseller.Metrics` exposes queries for:

- raw event listing
- per-user usage
- per-product usage
- platform totals
- daily platform totals
- top users by cost
- top products by cost
- provider/operation error summaries

Admin UI routes:

- `/admin/api-usage-events`
- `/admin/usage-dashboard`

## Remaining Gaps

- trial quota semantics need an explicit product decision
- seat-based billing is not tied into metrics or limits
- hard ceilings and monthly quotas are separate concepts and should stay documented as such

## Source of Truth

- context: `lib/reseller/metrics.ex`
- estimator: `lib/reseller/metrics/cost_estimator.ex`
- summarizer: `lib/reseller/metrics/usage_summarizer.ex`
- schema: `lib/reseller/metrics/api_usage_event.ex`
- schema: `lib/reseller/metrics/user_usage_summary.ex`
