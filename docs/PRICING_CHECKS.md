# Pricing and Limits Checks

This file records the remaining pricing/billing items worth revisiting after the current implementation pass.

## Verified in Code

- registration starts users as `plan_status: "trialing"` with `trial_ends_at`
- `GET /api/v1/me` exposes plan and add-on fields
- `GET /api/v1/me/usage` exists
- addon credits are added to the effective plan limit in `Reseller.Metrics.check_plan_limit/1`
- `generate_lifestyle_images` is gated through `Metrics.check_processing_limit/1`

## Remaining Review Items

### 1. Trial semantics

Registration leaves `plan: "free"` while setting `plan_status: "trialing"`.

Implication:

- trial users currently follow the free-plan branch in `check_processing_limit/1`
- that means daily hard ceilings apply, not paid-plan monthly quotas

Question:

- is that intentional product behavior, or should trial users map to a paid plan tier for quota purposes?

### 2. Seat enforcement

Pricing UI sells an `Extra Seat` add-on, but the app does not currently implement multi-user workspace seats.

Question:

- should this stay as roadmap copy, or should seat-aware authorization and invitations be added?

### 3. Annual billing truth

Annual pricing is rendered on `/pricing`, but the actual rollout status depends on LemonSqueezy variant configuration.

Question:

- should annual pricing remain visible in all environments, or be hidden unless variants are configured?

## Source of Truth

- billing state: `lib/reseller/billing.ex`
- plan metadata: `lib/reseller/billing/plans.ex`
- limits: `lib/reseller/metrics.ex`
- pricing page: `lib/reseller_web/live/pricing_live.ex`
