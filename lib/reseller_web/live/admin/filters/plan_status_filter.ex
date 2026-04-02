defmodule ResellerWeb.Admin.Filters.PlanStatusFilter do
  use Backpex.Filters.Select

  @impl Backpex.Filter
  def label, do: "Plan Status"

  @impl Backpex.Filters.Select
  def prompt, do: "All statuses"

  @impl Backpex.Filters.Select
  def options(_assigns) do
    [
      {"free", "free"},
      {"trialing", "trialing"},
      {"active", "active"},
      {"canceling", "canceling"},
      {"past_due", "past_due"},
      {"expired", "expired"}
    ]
  end
end
