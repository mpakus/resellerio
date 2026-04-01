defmodule Reseller.Metrics.UsageSummarizer do
  @moduledoc """
  Rolls up `api_usage_events` for a given user and date into a single
  `user_usage_summaries` row. Safe to call multiple times (upsert).
  """

  import Ecto.Query, warn: false

  alias Reseller.Metrics.ApiUsageEvent
  alias Reseller.Metrics.UserUsageSummary
  alias Reseller.Repo

  @spec run(pos_integer(), Date.t()) :: {:ok, UserUsageSummary.t()} | {:error, Ecto.Changeset.t()}
  def run(user_id, date \\ Date.utc_today()) when is_integer(user_id) do
    start_dt = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC")

    agg =
      ApiUsageEvent
      |> where(
        [e],
        e.user_id == ^user_id and
          e.inserted_at >= ^start_dt and
          e.inserted_at < ^end_dt
      )
      |> group_by([e], e.provider)
      |> select([e], {
        e.provider,
        count(e.id),
        coalesce(sum(e.total_tokens), 0),
        coalesce(sum(e.image_count), 0),
        coalesce(sum(e.cost_usd), 0)
      })
      |> Repo.all()

    summary_attrs = build_summary(user_id, date, agg)

    existing = Repo.get_by(UserUsageSummary, user_id: user_id, date: date)

    result =
      case existing do
        nil ->
          %UserUsageSummary{}
          |> UserUsageSummary.upsert_changeset(summary_attrs)
          |> Repo.insert()

        row ->
          row
          |> UserUsageSummary.upsert_changeset(summary_attrs)
          |> Repo.update()
      end

    result
  end

  defp build_summary(user_id, date, rows) do
    base = %{
      user_id: user_id,
      date: date,
      gemini_calls: 0,
      gemini_tokens: 0,
      gemini_images: 0,
      serp_api_calls: 0,
      photoroom_calls: 0,
      total_cost_usd: Decimal.new(0)
    }

    Enum.reduce(rows, base, fn {provider, calls, tokens, images, cost}, acc ->
      cost_dec = to_decimal(cost)

      case provider do
        "gemini" ->
          acc
          |> Map.put(:gemini_calls, calls)
          |> Map.put(:gemini_tokens, tokens)
          |> Map.put(:gemini_images, images)
          |> Map.update!(:total_cost_usd, &Decimal.add(&1, cost_dec))

        "serp_api" ->
          acc
          |> Map.put(:serp_api_calls, calls)
          |> Map.update!(:total_cost_usd, &Decimal.add(&1, cost_dec))

        "photoroom" ->
          acc
          |> Map.put(:photoroom_calls, calls)
          |> Map.update!(:total_cost_usd, &Decimal.add(&1, cost_dec))

        _ ->
          Map.update!(acc, :total_cost_usd, &Decimal.add(&1, cost_dec))
      end
    end)
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(nil), do: Decimal.new(0)
  defp to_decimal(n) when is_number(n), do: Decimal.from_float(n / 1)
  defp to_decimal(n) when is_binary(n), do: Decimal.new(n)
  defp to_decimal(_), do: Decimal.new(0)
end
