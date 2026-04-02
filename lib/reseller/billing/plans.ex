defmodule Reseller.Billing.Plans do
  @moduledoc """
  Plan definitions and monthly limit lookups.

  Each plan defines how many AI operations a user may perform per calendar month.
  Limits are checked against `api_usage_events` aggregated by user and month,
  with any `addon_credits` deducted from usage before the check.
  """

  @plans %{
    "free" => %{
      name: "Free",
      monthly_usd: 0,
      ai_drafts: 5,
      background_removals: 15,
      lifestyle: 0,
      price_research: 5
    },
    "starter" => %{
      name: "Starter",
      monthly_usd: 19,
      ai_drafts: 50,
      background_removals: 150,
      lifestyle: 150,
      price_research: 50
    },
    "growth" => %{
      name: "Growth",
      monthly_usd: 39,
      ai_drafts: 250,
      background_removals: 750,
      lifestyle: 750,
      price_research: 250
    },
    "pro" => %{
      name: "Pro",
      monthly_usd: 79,
      ai_drafts: 1000,
      background_removals: 3000,
      lifestyle: 3000,
      price_research: 1000
    }
  }

  @valid_plans Map.keys(@plans)

  @doc """
  Returns the limit map for the given plan name.
  Falls back to the "free" plan for unknown plan names.
  """
  @spec limits_for(String.t()) :: map()
  def limits_for(plan) when plan in @valid_plans, do: Map.fetch!(@plans, plan)
  def limits_for(_), do: Map.fetch!(@plans, "free")

  @doc """
  Returns the current plan limits for the given user struct.
  """
  @spec limits_for_user(map()) :: map()
  def limits_for_user(%{plan: plan}), do: limits_for(plan)

  @doc """
  Returns all plan definitions, ordered from cheapest to most expensive.
  """
  @spec all() :: [map()]
  def all do
    ["free", "starter", "growth", "pro"]
    |> Enum.map(fn key -> Map.put(@plans[key], :key, key) end)
  end

  @doc """
  Returns the plan metadata map for a given plan key (includes name and price).
  """
  @spec plan_info(String.t()) :: map() | nil
  def plan_info(plan), do: @plans[plan]

  @doc """
  Returns the list of valid plan name strings.
  """
  @spec valid_plans() :: [String.t()]
  def valid_plans, do: @valid_plans
end
