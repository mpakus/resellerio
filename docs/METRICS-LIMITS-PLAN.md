# ResellerIO Metrics & Limits Plan

## 1. Goals

1. **Count every external API call** to Gemini, SerpApi, and Photoroom — per product and per user.
2. **Track which resource** was consumed (which Gemini operation, which SerpApi engine, which Photoroom edit variant).
3. **Estimate cost** for each call and accumulate per-product and per-user totals.
4. **Expose admin dashboards** in Backpex showing aggregate usage, per-user breakdowns, and per-product breakdowns.
5. **Enforce per-user limits** so a single user cannot exhaust shared API quotas.

---

## 2. What to Count

### 2.1 Gemini (via `Reseller.AI.Providers.Gemini`)

Each call to `execute_request/5` is one billable API call. Operations and their current model mapping:

| Operation | Method | Notes |
|---|---|---|
| `recognition` | `generateContent` | 1 call, N images embedded |
| `reconciliation` | `generateContent` | 1 call, triggered only when confidence is low |
| `description` | `generateContent` | 1 call |
| `price_research_grounded` | `generateContent` | 1 call with Google Search grounding |
| `price_research` | `generateContent` | 1 call (structured JSON follow-up) |
| `marketplace_listing` | `generateContent` | 1 call per selected marketplace |
| `lifestyle_image` | `generateContent` | 1 call per scene request |

Token counts are already returned in `usageMetadata` from the Gemini response (`promptTokenCount`, `candidatesTokenCount`, `totalTokenCount`). These must be captured and persisted.

Input images count against token usage; the number of images sent per call should also be recorded.

### 2.2 SerpApi (via `Reseller.Search.Providers.SerpApi`)

| Operation | Engine | Trigger |
|---|---|---|
| `lens_matches` | `google_lens` | Fired when Gemini recognition confidence is low |
| `shopping_matches` | configured shopping engine | Fired during every price research step |

SerpApi charges per search. No sub-unit (token) granularity is available, so count = 1 per call.

### 2.3 Photoroom (via `Reseller.Media.Processors.Photoroom`)

| Operation | Notes |
|---|---|
| `process_image` (background removal) | 1 call per original image, once per product processing run |

Photoroom charges per edit. Count = 1 per call. `byte_size` of the result image is available in the response.

---

## 3. Cost Reference (Current Rates)

These are reference rates as of mid-2025. Store them in application config so they can be updated without code changes.

### Gemini (Flash/Pro)
| Model tier | Input tokens | Output tokens |
|---|---|---|
| `gemini-2.0-flash` | $0.10 / 1M tokens | $0.40 / 1M tokens |
| `gemini-2.0-flash` (image input) | $0.0258 / image | — |
| `gemini-2.0-pro` | $1.25 / 1M tokens | $10.00 / 1M tokens |

### SerpApi
| Plan | Cost |
|---|---|
| Pay-as-you-go | ~$0.0025 / search (400 searches/$1) |

### Photoroom
| Plan | Cost |
|---|---|
| Pay-as-you-go | ~$0.01 / edit |

---

## 4. New Schema: `api_usage_events`

A single denormalized append-only table captures every external API call.

```elixir
# migration: create_api_usage_events
create table(:api_usage_events) do
  add :user_id,         references(:users, on_delete: :nilify_all), null: true
  add :product_id,      references(:products, on_delete: :nilify_all), null: true
  add :provider,        :string, null: false   # "gemini" | "serp_api" | "photoroom"
  add :operation,       :string, null: false   # "recognition" | "description" | "price_research" | ...
  add :model,           :string                # model name for Gemini; null for others
  add :status,          :string, null: false   # "success" | "error"
  add :http_status,     :integer               # raw HTTP response status
  add :request_count,   :integer, default: 1  # always 1; reserved for future batching
  add :image_count,     :integer, default: 0  # images sent in this call
  add :input_tokens,    :integer              # Gemini promptTokenCount
  add :output_tokens,   :integer              # Gemini candidatesTokenCount
  add :total_tokens,    :integer              # Gemini totalTokenCount
  add :cost_usd,        :decimal, precision: 12, scale: 8  # estimated cost in USD
  add :duration_ms,     :integer              # wall-clock latency of the HTTP call
  add :error_code,      :string               # provider error code if status = "error"
  add :metadata,        :map, default: %{}    # arbitrary extra context (scene_key, marketplace, etc.)

  timestamps(type: :utc_datetime, updated_at: false)
end

create index(:api_usage_events, [:user_id])
create index(:api_usage_events, [:product_id])
create index(:api_usage_events, [:provider, :operation])
create index(:api_usage_events, [:user_id, :inserted_at])
create index(:api_usage_events, [:product_id, :inserted_at])
create index(:api_usage_events, [:inserted_at])
```

The table is **append-only** — no updates. Old rows may be archived or deleted by a retention job.

---

## 5. New Schema: `user_usage_summaries`

A materialized daily summary per user to make admin queries cheap.

```elixir
# migration: create_user_usage_summaries
create table(:user_usage_summaries) do
  add :user_id,          references(:users, on_delete: :delete_all), null: false
  add :date,             :date, null: false
  add :gemini_calls,     :integer, default: 0
  add :gemini_tokens,    :integer, default: 0
  add :gemini_images,    :integer, default: 0
  add :serp_api_calls,   :integer, default: 0
  add :photoroom_calls,  :integer, default: 0
  add :total_cost_usd,   :decimal, precision: 12, scale: 4

  timestamps(type: :utc_datetime)
end

create unique_index(:user_usage_summaries, [:user_id, :date])
```

Summaries are upserted by a lightweight background job that runs after each product processing run completes.

---

## 6. New Bounded Context: `Reseller.Metrics`

```
lib/reseller/metrics.ex
lib/reseller/metrics/api_usage_event.ex
lib/reseller/metrics/user_usage_summary.ex
lib/reseller/metrics/cost_estimator.ex
lib/reseller/metrics/usage_summarizer.ex
```

### `Reseller.Metrics`

Public API:

```elixir
# Record a single completed API call
@spec record_event(map()) :: {:ok, ApiUsageEvent.t()} | {:error, Ecto.Changeset.t()}
def record_event(attrs)

# Query aggregated usage for a user
@spec usage_for_user(pos_integer(), keyword()) :: map()
def usage_for_user(user_id, opts \\ [])

# Query aggregated usage for a product
@spec usage_for_product(pos_integer()) :: map()
def usage_for_product(product_id)

# List raw events with filters (admin use)
@spec list_events(keyword()) :: [ApiUsageEvent.t()]
def list_events(filters \\ [])

# Upsert daily summary for a user (called after processing runs)
@spec refresh_user_summary(pos_integer(), Date.t()) :: {:ok, UserUsageSummary.t()}
def refresh_user_summary(user_id, date \\ Date.utc_today())
```

### `Reseller.Metrics.CostEstimator`

Reads pricing config from `Application.get_env/2` and computes `cost_usd` before insert:

```elixir
@spec estimate(provider :: atom(), operation :: atom(), map()) :: Decimal.t()
def estimate(:gemini, operation, %{model: model, input_tokens: n, output_tokens: m, image_count: k})
def estimate(:serp_api, _operation, _attrs)
def estimate(:photoroom, _operation, _attrs)
```

### `Reseller.Metrics.UsageSummarizer`

Runs a single SQL `GROUP BY user_id, date` over `api_usage_events` and upserts into `user_usage_summaries`:

```elixir
@spec run(user_id :: pos_integer(), date :: Date.t()) :: {:ok, UserUsageSummary.t()}
def run(user_id, date)
```

---

## 7. Instrumentation Points

### 7.1 Gemini — `Reseller.AI.Providers.Gemini`

Wrap `execute_request/5`. After a successful or error response, emit an event:

```elixir
defp execute_and_record(request, opts) do
  t0 = System.monotonic_time(:millisecond)
  result = execute_request(request, opts)
  duration_ms = System.monotonic_time(:millisecond) - t0

  {status, http_status, usage, error_code} = extract_telemetry(result, request)

  Reseller.Metrics.record_event(%{
    user_id:       Keyword.get(opts, :user_id),
    product_id:    Keyword.get(opts, :product_id),
    provider:      "gemini",
    operation:     to_string(request.operation),
    model:         request.model,
    status:        status,
    http_status:   http_status,
    image_count:   count_images(request),
    input_tokens:  get_in(usage, ["promptTokenCount"]),
    output_tokens: get_in(usage, ["candidatesTokenCount"]),
    total_tokens:  get_in(usage, ["totalTokenCount"]),
    duration_ms:   duration_ms,
    error_code:    error_code,
    metadata:      %{"operation" => to_string(request.operation)}
  })

  result
end
```

`user_id` and `product_id` are passed via `opts` from the worker layer. The callers in `AIProductProcessor` and `LifestyleImageGenerator` already hold `product` structs and must propagate these opts.

### 7.2 SerpApi — `Reseller.Search.Providers.SerpApi`

Wrap `execute_request/2` similarly. No token metadata is returned by SerpApi.

### 7.3 Photoroom — `Reseller.Media.Processors.Photoroom`

Wrap `execute_request/2` similarly. Record `image_count: 1` and `byte_size` in metadata.

### 7.4 Worker opt propagation

`AIProductProcessor.process/2` receives `opts` from `ProductProcessingWorker`. Extend `ProductProcessingWorker.perform/2` to inject `user_id` and `product_id` into opts before dispatching to the processor:

```elixir
opts = opts
  |> Keyword.put(:user_id, run.product.user_id)
  |> Keyword.put(:product_id, run.product_id)
```

The same pattern applies to `LifestyleImageGenerator.generate/2`.

---

## 8. Limits and Guardrails

### 8.1 Per-user daily limits

Store limits in config (overridable per user via a future `user_limits` table or an admin override column on `users`):

```elixir
# config/config.exs
config :reseller, Reseller.Metrics,
  daily_limits: %{
    gemini_calls:    100,
    serp_api_calls:  50,
    photoroom_calls: 100,
    cost_usd:        Decimal.new("5.00")
  }
```

### 8.2 Limit check

Add `Reseller.Metrics.check_limit/2` called before each processing run enqueue:

```elixir
@spec check_limit(user_id :: pos_integer(), resource :: atom()) ::
  :ok | {:error, :limit_exceeded, map()}
def check_limit(user_id, resource)
```

If a limit is exceeded, `Workers.start_product_processing/2` returns `{:error, :limit_exceeded, details}` and the API/LiveView surface surfaces a clear message.

### 8.3 Future: per-user overrides

A `user_limits` table (or JSON column on `users`) can store per-user overrides for any limit dimension. The `check_limit/2` function checks user overrides first, then falls back to global config.

---

## 9. Admin Dashboard in Backpex

### 9.1 New Backpex resource: `ApiUsageEventLive`

Path: `/admin/api-usage-events`

Fields:

| Field | Type | Notes |
|---|---|---|
| `inserted_at` | DateTime | when the call was made |
| `user_id` | BelongsTo User | linked user |
| `product_id` | BelongsTo Product | linked product |
| `provider` | Text | "gemini" / "serp_api" / "photoroom" |
| `operation` | Text | operation name |
| `model` | Text | Gemini model |
| `status` | Text | "success" / "error" |
| `total_tokens` | Number | Gemini total tokens |
| `image_count` | Number | images sent |
| `cost_usd` | Text | formatted cost |
| `duration_ms` | Number | latency |
| `error_code` | Text | error code if failed |

Supported actions: `index`, `show` (no create/update/delete — append-only).

Filters: `provider`, `operation`, `status`, date range.

### 9.2 Metrics panel on `UserLive` show page

Add a custom Backpex panel to the existing `ResellerWeb.Admin.UserLive` show page:

- Total Gemini calls (all time / last 30 days)
- Total Gemini tokens consumed (all time / last 30 days)
- Total SerpApi calls
- Total Photoroom calls
- Estimated total cost (USD)
- Daily usage chart (sparkline or table for the last 30 days, sourced from `user_usage_summaries`)

### 9.3 Metrics panel on `ProductLive` show page

Add a custom panel to the existing `ResellerWeb.Admin.ProductLive` show page:

- Per-operation call counts for this product
- Token totals by operation
- Estimated per-product cost
- Timeline of calls (table of raw `api_usage_events` rows filtered by `product_id`)

### 9.4 Global usage dashboard LiveView

Add a standalone admin LiveView at `/admin/usage-dashboard`:

```
lib/reseller_web/live/admin/usage_dashboard_live.ex
```

Sections:

1. **Platform totals** (all time and rolling 30 days): calls, tokens, images, cost — broken down by provider.
2. **Top users by cost** (last 30 days): table of user + cost + call counts.
3. **Top products by cost** (last 30 days): table of product + user + cost + call counts.
4. **Daily trend**: table or chart of aggregate `cost_usd`, `gemini_calls`, `serp_api_calls`, `photoroom_calls` per day for the last 30 days.
5. **Error rate**: count of `status = "error"` events by provider and operation.

All queries are read-only aggregates over `api_usage_events` and `user_usage_summaries`.

---

## 10. New Files Summary

| Path | Purpose |
|---|---|
| `priv/repo/migrations/TIMESTAMP_create_api_usage_events.exs` | `api_usage_events` table |
| `priv/repo/migrations/TIMESTAMP_create_user_usage_summaries.exs` | `user_usage_summaries` table |
| `lib/reseller/metrics.ex` | context façade |
| `lib/reseller/metrics/api_usage_event.ex` | Ecto schema |
| `lib/reseller/metrics/user_usage_summary.ex` | Ecto schema |
| `lib/reseller/metrics/cost_estimator.ex` | pricing calculations |
| `lib/reseller/metrics/usage_summarizer.ex` | daily rollup |
| `lib/reseller_web/live/admin/api_usage_event_live.ex` | Backpex resource |
| `lib/reseller_web/live/admin/usage_dashboard_live.ex` | global dashboard LiveView |

Modified files:

| Path | Change |
|---|---|
| `lib/reseller/ai/providers/gemini.ex` | wrap `execute_request` with metrics emission |
| `lib/reseller/search/providers/serp_api.ex` | wrap `execute_request` with metrics emission |
| `lib/reseller/media/processors/photoroom.ex` | wrap `execute_request` with metrics emission |
| `lib/reseller/workers/product_processing_worker.ex` | inject `user_id` + `product_id` into opts |
| `lib/reseller/workers/lifestyle_image_generator.ex` | propagate `user_id` + `product_id` through opts |
| `lib/reseller_web/live/admin/user_live.ex` | add usage metrics panel |
| `lib/reseller_web/live/admin/product_live.ex` | add usage metrics panel |
| `lib/reseller_web/router.ex` | add `/admin/api-usage-events` and `/admin/usage-dashboard` routes |
| `config/config.exs` | add `Reseller.Metrics` config block with pricing and daily limits |
| `docs/ARCHITECTURE.md` | add `Reseller.Metrics` context, schemas, and admin surfaces |

---

## 11. Testing Plan

- Unit tests for `Reseller.Metrics.CostEstimator` covering all providers and edge cases (nil tokens, zero images).
- Unit tests for `Reseller.Metrics.check_limit/2` covering under-limit, at-limit, and over-limit paths.
- Context tests for `Reseller.Metrics.record_event/1` and `usage_for_user/2`.
- Integration test: a fake `AIProductProcessor` run records expected event counts via a fake `record_event` or by asserting DB rows.
- Admin LiveView tests covering `ApiUsageEventLive` index/show and `UsageDashboardLive` render with fixture data.
- Regression tests: ensure that a `record_event` failure does **not** halt the processing pipeline (metrics are best-effort — errors must be logged, not raised).

---

## 12. Delivery Milestones

| Step | Scope | Status |
|---|---|---|
| ML-1 | Migrations, `Reseller.Metrics` context, schemas, `CostEstimator` | ✅ Done |
| ML-2 | Instrumentation in Gemini, SerpApi, Photoroom providers | ✅ Done |
| ML-3 | Worker opt propagation (`user_id`, `product_id`) | ✅ Done |
| ML-4 | `UsageSummarizer` daily rollup + `check_limit` + refresh after runs | ✅ Done |
| ML-5 | `ApiUsageEventLive` Backpex resource + router wiring | ✅ Done |
| ML-6 | Usage panels on `UserLive` and `ProductLive` show pages | ✅ Done |
| ML-7 | `UsageDashboardLive` global dashboard at `/admin/usage-dashboard` | ✅ Done |
| ML-8 | Tests (context, cost estimator, summarizer, admin LiveViews) | ✅ Done |
| ML-9 | Update `ARCHITECTURE.md`, `PLANS.md`, `METRICS-LIMITS-PLAN.md` | ✅ Done |

---

## 13. Open Questions

1. **Retention**: how long should raw `api_usage_events` rows be kept? (suggestion: 90 days, archivable to cold storage)
2. **Per-user limit overrides**: column on `users` vs. a separate `user_limits` table?
3. **Real-time vs. batched summarization**: should `UsageSummarizer` run after every processing run, or on a nightly schedule?
4. **Alerting**: should an admin be emailed when a user approaches their daily cost limit?
5. **Lifestyle image retry cost**: when a `lifestyle_image` scene fails and is retried manually, should the retry count separately or be linked to the original run?
