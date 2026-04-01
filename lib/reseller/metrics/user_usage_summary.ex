defmodule Reseller.Metrics.UserUsageSummary do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_usage_summaries" do
    field :date, :date
    field :gemini_calls, :integer, default: 0
    field :gemini_tokens, :integer, default: 0
    field :gemini_images, :integer, default: 0
    field :serp_api_calls, :integer, default: 0
    field :photoroom_calls, :integer, default: 0
    field :total_cost_usd, :decimal

    belongs_to :user, Reseller.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def upsert_changeset(summary, attrs) do
    summary
    |> cast(attrs, [
      :user_id,
      :date,
      :gemini_calls,
      :gemini_tokens,
      :gemini_images,
      :serp_api_calls,
      :photoroom_calls,
      :total_cost_usd
    ])
    |> validate_required([:user_id, :date])
  end
end
