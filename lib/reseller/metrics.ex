defmodule Reseller.Metrics do
  @moduledoc """
  Tracks external API usage (Gemini, SerpApi, Photoroom) per product and per user.

  ## Key responsibilities

  - Record every outgoing API call as an `ApiUsageEvent`.
  - Estimate the USD cost of each call via `CostEstimator`.
  - Roll up daily summaries per user via `UsageSummarizer`.
  - Provide aggregate queries for admin dashboards.
  - Gate new processing runs when a user exceeds configured daily limits.

  ## Configuration

      config :reseller, Reseller.Metrics,
        daily_limits: %{
          gemini_calls: 200,
          serp_api_calls: 100,
          photoroom_calls: 200,
          cost_usd: Decimal.new("10.00")
        },
        pricing: [
          gemini: [
            default_input_per_million: "0.10",
            default_output_per_million: "0.40",
            default_per_image: "0",
            models: %{
              "gemini-2.5-flash" => %{
                input_per_million: "0.10",
                output_per_million: "0.40",
                per_image: "0"
              },
              "gemini-2.0-pro" => %{
                input_per_million: "1.25",
                output_per_million: "10.00",
                per_image: "0"
              }
            }
          ],
          serp_api: [per_call: "0.0025"],
          photoroom: [per_edit: "0.01"]
        ]
  """

  import Ecto.Query, warn: false

  alias Reseller.Metrics.ApiUsageEvent
  alias Reseller.Metrics.CostEstimator
  alias Reseller.Metrics.UsageSummarizer
  alias Reseller.Metrics.UserUsageSummary
  alias Reseller.Repo

  @doc """
  Records a single completed external API call.

  Estimates cost before insertion. Failures are logged but never raised so
  that a metrics write error cannot interrupt the processing pipeline.
  """
  @spec record_event(map()) :: {:ok, ApiUsageEvent.t()} | {:error, Ecto.Changeset.t()}
  def record_event(attrs) when is_map(attrs) do
    provider = normalize_provider(attrs[:provider] || attrs["provider"])
    operation = to_string(attrs[:operation] || attrs["operation"] || "")

    cost =
      CostEstimator.estimate(provider, String.to_existing_atom(operation_key(operation)), attrs)

    full_attrs =
      attrs
      |> Map.put(:provider, to_string(provider))
      |> Map.put(:operation, operation)
      |> Map.put(:cost_usd, cost)

    %ApiUsageEvent{}
    |> ApiUsageEvent.create_changeset(full_attrs)
    |> Repo.insert()
  end

  @doc """
  Records an event, logging on failure without raising.
  Safe to call from provider instrumentation code.
  """
  @spec record_event_safe(map()) :: :ok
  def record_event_safe(attrs) when is_map(attrs) do
    try do
      case record_event(attrs) do
        {:ok, _event} ->
          :ok

        {:error, changeset} ->
          require Logger

          Logger.warning(
            "Metrics: failed to record API usage event: #{inspect(changeset.errors)}"
          )

          :ok
      end
    rescue
      e ->
        require Logger
        Logger.warning("Metrics: skipped recording API usage event: #{Exception.message(e)}")
        :ok
    catch
      :exit, _ ->
        :ok
    end
  end

  @doc """
  Returns aggregated usage counts and costs for a user.

  Options:
  - `:since` – `DateTime` lower bound (default: beginning of today)
  - `:until` – `DateTime` upper bound (default: now)
  """
  @spec usage_for_user(pos_integer(), keyword()) :: map()
  def usage_for_user(user_id, opts \\ []) when is_integer(user_id) do
    {since, until_dt} = time_window(opts)

    rows =
      ApiUsageEvent
      |> where([e], e.user_id == ^user_id)
      |> where([e], e.inserted_at >= ^since and e.inserted_at <= ^until_dt)
      |> group_by([e], e.provider)
      |> select([e], %{
        provider: e.provider,
        calls: count(e.id),
        total_tokens: coalesce(sum(e.total_tokens), 0),
        total_images: coalesce(sum(e.image_count), 0),
        total_cost_usd: coalesce(sum(e.cost_usd), 0)
      })
      |> Repo.all()

    aggregate_usage(rows)
  end

  @doc """
  Returns aggregated usage counts and costs for a single product.
  """
  @spec usage_for_product(pos_integer()) :: map()
  def usage_for_product(product_id) when is_integer(product_id) do
    rows =
      ApiUsageEvent
      |> where([e], e.product_id == ^product_id)
      |> group_by([e], [e.provider, e.operation])
      |> select([e], %{
        provider: e.provider,
        operation: e.operation,
        calls: count(e.id),
        total_tokens: coalesce(sum(e.total_tokens), 0),
        total_images: coalesce(sum(e.image_count), 0),
        total_cost_usd: coalesce(sum(e.cost_usd), 0)
      })
      |> Repo.all()

    %{
      by_operation: rows,
      total_calls: Enum.sum(Enum.map(rows, & &1.calls)),
      total_cost_usd: rows |> Enum.map(& &1.total_cost_usd) |> sum_decimals()
    }
  end

  @doc """
  Lists raw usage events with optional filters.

  Options:
  - `:user_id`
  - `:product_id`
  - `:provider`
  - `:operation`
  - `:status`
  - `:since` – DateTime
  - `:until` – DateTime
  - `:limit` (default 50)
  - `:offset` (default 0)
  """
  @spec list_events(keyword()) :: [ApiUsageEvent.t()]
  def list_events(filters \\ []) do
    limit = Keyword.get(filters, :limit, 50)
    offset = Keyword.get(filters, :offset, 0)

    ApiUsageEvent
    |> maybe_filter(:user_id, Keyword.get(filters, :user_id))
    |> maybe_filter(:product_id, Keyword.get(filters, :product_id))
    |> maybe_filter(:provider, Keyword.get(filters, :provider))
    |> maybe_filter(:operation, Keyword.get(filters, :operation))
    |> maybe_filter(:status, Keyword.get(filters, :status))
    |> maybe_since(Keyword.get(filters, :since))
    |> maybe_until(Keyword.get(filters, :until))
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Returns per-day platform totals for the admin dashboard.

  Covers the last `days` calendar days (default 30).
  """
  @spec platform_daily_totals(keyword()) :: [map()]
  def platform_daily_totals(opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    since = Date.add(Date.utc_today(), -days)
    since_dt = DateTime.new!(since, ~T[00:00:00], "Etc/UTC")

    ApiUsageEvent
    |> where([e], e.inserted_at >= ^since_dt)
    |> group_by([e], fragment("DATE(? AT TIME ZONE 'UTC')", e.inserted_at))
    |> order_by([e], asc: fragment("DATE(? AT TIME ZONE 'UTC')", e.inserted_at))
    |> select([e], %{
      date: fragment("DATE(? AT TIME ZONE 'UTC')", e.inserted_at),
      calls: count(e.id),
      total_tokens: coalesce(sum(e.total_tokens), 0),
      total_cost_usd: coalesce(sum(e.cost_usd), 0)
    })
    |> Repo.all()
  end

  @doc """
  Returns the top N users by estimated cost over the last `days` calendar days.
  """
  @spec top_users_by_cost(keyword()) :: [map()]
  def top_users_by_cost(opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    limit_n = Keyword.get(opts, :limit, 10)
    since = Date.add(Date.utc_today(), -days)
    since_dt = DateTime.new!(since, ~T[00:00:00], "Etc/UTC")

    ApiUsageEvent
    |> where([e], e.inserted_at >= ^since_dt and not is_nil(e.user_id))
    |> group_by([e], e.user_id)
    |> order_by([e], desc: coalesce(sum(e.cost_usd), 0))
    |> limit(^limit_n)
    |> select([e], %{
      user_id: e.user_id,
      calls: count(e.id),
      total_tokens: coalesce(sum(e.total_tokens), 0),
      total_cost_usd: coalesce(sum(e.cost_usd), 0)
    })
    |> Repo.all()
  end

  @doc """
  Returns the top N products by estimated cost over the last `days` calendar days.
  """
  @spec top_products_by_cost(keyword()) :: [map()]
  def top_products_by_cost(opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    limit_n = Keyword.get(opts, :limit, 10)
    since = Date.add(Date.utc_today(), -days)
    since_dt = DateTime.new!(since, ~T[00:00:00], "Etc/UTC")

    ApiUsageEvent
    |> where([e], e.inserted_at >= ^since_dt and not is_nil(e.product_id))
    |> group_by([e], e.product_id)
    |> order_by([e], desc: coalesce(sum(e.cost_usd), 0))
    |> limit(^limit_n)
    |> select([e], %{
      product_id: e.product_id,
      calls: count(e.id),
      total_tokens: coalesce(sum(e.total_tokens), 0),
      total_cost_usd: coalesce(sum(e.cost_usd), 0)
    })
    |> Repo.all()
  end

  @doc """
  Returns error counts by provider and operation for the last `days` days.
  """
  @spec error_summary(keyword()) :: [map()]
  def error_summary(opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    since = Date.add(Date.utc_today(), -days)
    since_dt = DateTime.new!(since, ~T[00:00:00], "Etc/UTC")

    ApiUsageEvent
    |> where([e], e.inserted_at >= ^since_dt and e.status == "error")
    |> group_by([e], [e.provider, e.operation])
    |> order_by([e], desc: count(e.id))
    |> select([e], %{
      provider: e.provider,
      operation: e.operation,
      error_count: count(e.id)
    })
    |> Repo.all()
  end

  @doc """
  Returns platform-wide total counts and cost for a given time window.

  Options: `:since`, `:until`
  """
  @spec platform_totals(keyword()) :: map()
  def platform_totals(opts \\ []) do
    {since, until_dt} = time_window(opts)

    rows =
      ApiUsageEvent
      |> where([e], e.inserted_at >= ^since and e.inserted_at <= ^until_dt)
      |> group_by([e], e.provider)
      |> select([e], %{
        provider: e.provider,
        calls: count(e.id),
        total_tokens: coalesce(sum(e.total_tokens), 0),
        total_images: coalesce(sum(e.image_count), 0),
        total_cost_usd: coalesce(sum(e.cost_usd), 0)
      })
      |> Repo.all()

    aggregate_usage(rows)
  end

  @doc """
  Checks whether a user has exceeded any of the configured daily limits.

  Returns `:ok` or `{:error, :limit_exceeded, details_map}`.
  """
  @spec check_limit(pos_integer()) :: :ok | {:error, :limit_exceeded, map()}
  def check_limit(user_id) when is_integer(user_id) do
    limits = daily_limits()
    today = Date.utc_today()

    summary =
      case Repo.get_by(UserUsageSummary, user_id: user_id, date: today) do
        nil ->
          %{
            gemini_calls: 0,
            serp_api_calls: 0,
            photoroom_calls: 0,
            total_cost_usd: Decimal.new(0)
          }

        row ->
          row
      end

    cond do
      exceeds?(summary.gemini_calls, limits[:gemini_calls]) ->
        {:error, :limit_exceeded,
         %{resource: "gemini_calls", used: summary.gemini_calls, limit: limits[:gemini_calls]}}

      exceeds?(summary.serp_api_calls, limits[:serp_api_calls]) ->
        {:error, :limit_exceeded,
         %{
           resource: "serp_api_calls",
           used: summary.serp_api_calls,
           limit: limits[:serp_api_calls]
         }}

      exceeds?(summary.photoroom_calls, limits[:photoroom_calls]) ->
        {:error, :limit_exceeded,
         %{
           resource: "photoroom_calls",
           used: summary.photoroom_calls,
           limit: limits[:photoroom_calls]
         }}

      cost_exceeds?(summary.total_cost_usd, limits[:cost_usd]) ->
        {:error, :limit_exceeded,
         %{
           resource: "cost_usd",
           used: summary.total_cost_usd,
           limit: limits[:cost_usd]
         }}

      true ->
        :ok
    end
  end

  @doc """
  Upserts the daily summary row for a user. Call after each processing run.
  """
  @spec refresh_user_summary(pos_integer(), Date.t()) ::
          {:ok, UserUsageSummary.t()} | {:error, Ecto.Changeset.t()}
  def refresh_user_summary(user_id, date \\ Date.utc_today()) do
    UsageSummarizer.run(user_id, date)
  end

  defp aggregate_usage(rows) do
    base = %{
      gemini_calls: 0,
      gemini_tokens: 0,
      gemini_images: 0,
      serp_api_calls: 0,
      photoroom_calls: 0,
      total_calls: 0,
      total_cost_usd: Decimal.new(0)
    }

    Enum.reduce(rows, base, fn row, acc ->
      cost = to_decimal(row.total_cost_usd)

      acc
      |> Map.update!(:total_calls, &(&1 + row.calls))
      |> Map.update!(:total_cost_usd, &Decimal.add(&1, cost))
      |> merge_provider_row(row)
    end)
  end

  defp merge_provider_row(acc, %{provider: "gemini"} = row) do
    acc
    |> Map.put(:gemini_calls, row.calls)
    |> Map.put(:gemini_tokens, row.total_tokens)
    |> Map.put(:gemini_images, row.total_images)
  end

  defp merge_provider_row(acc, %{provider: "serp_api"} = row) do
    Map.put(acc, :serp_api_calls, row.calls)
  end

  defp merge_provider_row(acc, %{provider: "photoroom"} = row) do
    Map.put(acc, :photoroom_calls, row.calls)
  end

  defp merge_provider_row(acc, _row), do: acc

  defp maybe_filter(query, _field, nil), do: query
  defp maybe_filter(query, field, value), do: where(query, [e], field(e, ^field) == ^value)

  defp maybe_since(query, nil), do: query
  defp maybe_since(query, since), do: where(query, [e], e.inserted_at >= ^since)

  defp maybe_until(query, nil), do: query
  defp maybe_until(query, until_dt), do: where(query, [e], e.inserted_at <= ^until_dt)

  defp time_window(opts) do
    since = Keyword.get(opts, :since, DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC"))
    until_dt = Keyword.get(opts, :until, DateTime.utc_now())
    {since, until_dt}
  end

  defp daily_limits do
    Application.get_env(:reseller, Reseller.Metrics, [])
    |> Keyword.get(:daily_limits, %{})
  end

  @doc """
  Returns monthly operation counts for a user, used for plan limit enforcement.

  Returns a map with keys: `:ai_drafts`, `:background_removals`, `:lifestyle`, `:price_research`.
  """
  @spec monthly_usage_for_user(pos_integer(), Date.t()) :: map()
  def monthly_usage_for_user(user_id, month \\ Date.utc_today()) do
    month_start = %{month | day: 1} |> Date.to_iso8601()

    month_start_dt =
      NaiveDateTime.from_iso8601!("#{month_start} 00:00:00") |> DateTime.from_naive!("Etc/UTC")

    rows =
      from(e in ApiUsageEvent,
        where: e.user_id == ^user_id,
        where: e.inserted_at >= ^month_start_dt,
        where: e.status == "success",
        select: {e.provider, e.operation, count(e.id)}
      )
      |> group_by([e], [e.provider, e.operation])
      |> Repo.all()

    base = %{ai_drafts: 0, background_removals: 0, lifestyle: 0, price_research: 0}

    Enum.reduce(rows, base, fn {provider, operation, count}, acc ->
      case {provider, operation} do
        {"gemini", op} when op in ["recognition", "description", "reconciliation"] ->
          Map.update!(acc, :ai_drafts, &(&1 + count))

        {"photoroom", _} ->
          Map.update!(acc, :background_removals, &(&1 + count))

        {"gemini", op} when op in ["lifestyle_image"] ->
          Map.update!(acc, :lifestyle, &(&1 + count))

        {"gemini", op} when op in ["price_research", "price_research_grounded"] ->
          Map.update!(acc, :price_research, &(&1 + count))

        {"serp_api", _} ->
          Map.update!(acc, :price_research, &(&1 + count))

        _ ->
          acc
      end
    end)
  end

  @doc """
  Checks whether a user (by struct) has exceeded their plan's monthly limits.

  Consults `Billing.Plans` for the user's plan limits, then subtracts any
  `addon_credits` from consumed counts before comparing.

  Users on the "free" plan (no subscription) are only governed by the existing
  daily API cost ceiling — no monthly op limits apply.

  Returns `:ok` or `{:error, :limit_exceeded, details}`.
  """
  @spec check_plan_limit(map()) :: :ok | {:error, :limit_exceeded, map()}
  def check_plan_limit(%{plan: plan}) when plan in [nil, "free"], do: :ok

  def check_plan_limit(%{plan: _} = user) do
    limits = Reseller.Billing.Plans.limits_for_user(user)
    usage = monthly_usage_for_user(user.id)
    credits = user.addon_credits || %{}

    checks = [
      {:ai_drafts, usage.ai_drafts, Map.get(credits, "ai_drafts", 0)},
      {:background_removals, usage.background_removals,
       Map.get(credits, "background_removals", 0)},
      {:lifestyle, usage.lifestyle, Map.get(credits, "lifestyle", 0)},
      {:price_research, usage.price_research, Map.get(credits, "price_research", 0)}
    ]

    Enum.find_value(checks, :ok, fn {op, used, addon_credit} ->
      plan_limit = Map.get(limits, op)
      effective_limit = (plan_limit || 0) + addon_credit

      if not is_nil(plan_limit) and used >= effective_limit do
        {:error, :limit_exceeded,
         %{
           operation: op,
           used: used,
           limit: plan_limit,
           addon_credits: addon_credit,
           upgrade_path: "https://resellerio.com/pricing"
         }}
      end
    end)
  end

  def check_plan_limit(_), do: :ok

  @doc """
  Combined limit gate for API processing actions.

  - Paid/trialing users: checked against monthly plan limits.
  - Free users: checked against the daily hard ceiling.

  Returns `:ok` or `{:error, :limit_exceeded, details}`.
  """
  @spec check_processing_limit(map()) :: :ok | {:error, :limit_exceeded, map()}
  def check_processing_limit(%{plan: plan, id: user_id} = _user) when plan in [nil, "free"] do
    case check_limit(user_id) do
      :ok ->
        :ok

      {:error, :limit_exceeded, details} ->
        {:error, :limit_exceeded,
         Map.merge(details, %{upgrade_path: "https://resellerio.com/pricing"})}
    end
  end

  def check_processing_limit(user), do: check_plan_limit(user)

  defp exceeds?(_used, nil), do: false
  defp exceeds?(used, limit) when is_integer(used) and is_integer(limit), do: used >= limit
  defp exceeds?(_used, _limit), do: false

  defp cost_exceeds?(_used, nil), do: false

  defp cost_exceeds?(used, limit) do
    used_dec = to_decimal(used)
    limit_dec = to_decimal(limit)
    Decimal.compare(used_dec, limit_dec) != :lt
  end

  defp normalize_provider(p) when is_atom(p), do: p
  defp normalize_provider("gemini"), do: :gemini
  defp normalize_provider("serp_api"), do: :serp_api
  defp normalize_provider("photoroom"), do: :photoroom

  defp normalize_provider(p) when is_binary(p) do
    try do
      String.to_existing_atom(p)
    rescue
      ArgumentError -> :unknown
    end
  end

  defp normalize_provider(_), do: :unknown

  defp operation_key(""), do: "unknown"

  defp operation_key(op) when is_binary(op) do
    if Enum.any?(
         [
           :recognition,
           :description,
           :price_research,
           :price_research_grounded,
           :reconciliation,
           :marketplace_listing,
           :lifestyle_image,
           :lens_matches,
           :shopping_matches,
           :process_image,
           :unknown
         ],
         &(Atom.to_string(&1) == op)
       ) do
      op
    else
      "unknown"
    end
  end

  defp sum_decimals(list) do
    Enum.reduce(list, Decimal.new(0), fn v, acc -> Decimal.add(acc, to_decimal(v)) end)
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(nil), do: Decimal.new(0)
  defp to_decimal(n) when is_number(n), do: Decimal.from_float(n / 1)
  defp to_decimal(n) when is_binary(n), do: Decimal.new(n)
  defp to_decimal(_), do: Decimal.new(0)
end
