# ResellerIO Pricing System — Audit Gaps

Last analysed: `Reseller.Billing`, `Reseller.Billing.Plans`, `Reseller.Metrics`,
`ResellerWeb.API.V1.ProductController`, `ResellerWeb.API.V1.UserJSON`.

## Open Issues

| # | Area | Issue | Severity |
|---|---|---|---|
| T1 | Trial | Trial not started on web or API registration — new users get `plan_status: "free"` immediately | 🔴 Critical |
| T2 | Trial | `users_expiring_within/2` excludes `"trialing"` users from reminder sweeps | 🟠 High |
| T3 | Trial | `users_past_expiry/0` excludes trialing users — lapsed trials stay `"trialing"` indefinitely | 🔴 Critical |
| T5 | Trial | No expired-trial gate on API or LiveView | 🟠 High |
| L1 | Limits | `generate_lifestyle_images` has no `check_plan_limit` call | 🔴 Critical |
| L2 | Limits | Workspace LiveView processing actions bypass monthly plan limits | 🟠 High |
| L3 | Limits | Addon credit math double-counts (effective_used = max(0, used - addon) is wrong; should be effective_limit = plan_limit + addon) | 🟡 Medium |
| L4 | Limits | Expired trial users bypass plan limits | 🟠 High |
| L5 | Limits | Daily hard ceiling and monthly plan limit are separate — `finalize_uploads` only calls `check_plan_limit` | 🟡 Medium |
| L6 | Limits | Free users have no daily limit gate in the API | 🟠 High |
| A1 | API | `GET /api/v1/me` does not expose `plan`, `plan_status`, `plan_period`, `plan_expires_at`, `trial_ends_at`, `addon_credits` | 🔴 Critical |
| A3 | API | No `GET /api/v1/me/usage` endpoint for mobile quota display | 🟡 Medium |
Note: A2 = L1, A4 = T1 (same issues from different angles).

## Recently Resolved

| # | Area | Resolution | Date |
|---|---|---|---|
| A5 | API | `402` `limit_exceeded` responses now return an absolute `upgrade_url` (`https://resellerio.com/pricing`) for mobile upgrade CTAs | 2026-04-02 |

## Recommended Fix Order

1. **T1/A4** — Start trial on registration (`register_user/1` + `AuthController.register/2`)
2. **A1** — Expose plan fields in `UserJSON`
3. **L1/A2** — Add `check_plan_limit` to `generate_lifestyle_images`
4. **T3** — Fix `users_past_expiry` to include trialing users
5. **L6** — Call daily `check_limit` for free users in `finalize_uploads`/`reprocess`
6. **T2** — Include trialing users in expiry reminder sweeps
7. **L3** — Fix addon credit math: `effective_limit = plan_limit + addon_credit`, compare `used >= effective_limit`
8. **A3** — `GET /api/v1/me/usage` returning current-month quota counts and limits
9. **L2/T5** — Add plan/trial gate to workspace LiveView processing actions
