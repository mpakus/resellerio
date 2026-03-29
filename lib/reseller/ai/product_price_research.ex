defmodule Reseller.AI.ProductPriceResearch do
  use Ecto.Schema
  import Ecto.Changeset

  schema "product_price_researches" do
    field :status, :string, default: "generated"
    field :provider, :string
    field :model, :string
    field :currency, :string, default: "USD"
    field :suggested_min_price, :decimal
    field :suggested_target_price, :decimal
    field :suggested_max_price, :decimal
    field :suggested_median_price, :decimal
    field :pricing_confidence, :float
    field :rationale_summary, :string
    field :market_signals, {:array, :string}, default: []
    field :comparable_results, :map, default: %{}
    field :raw_payload, :map, default: %{}

    belongs_to :product, Reseller.Catalog.Product

    timestamps(type: :utc_datetime)
  end

  def create_changeset(price_research, attrs) do
    price_research
    |> cast(attrs, [
      :status,
      :provider,
      :model,
      :currency,
      :suggested_min_price,
      :suggested_target_price,
      :suggested_max_price,
      :suggested_median_price,
      :pricing_confidence,
      :rationale_summary,
      :market_signals,
      :comparable_results,
      :raw_payload
    ])
    |> validate_required([:status, :currency])
    |> validate_inclusion(:status, ~w(generated review failed))
    |> validate_length(:currency, min: 3, max: 3)
    |> validate_number(:suggested_min_price, greater_than_or_equal_to: 0)
    |> validate_number(:suggested_target_price, greater_than_or_equal_to: 0)
    |> validate_number(:suggested_max_price, greater_than_or_equal_to: 0)
    |> validate_number(:suggested_median_price, greater_than_or_equal_to: 0)
    |> validate_number(:pricing_confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> unique_constraint(:product_id)
  end

  def update_changeset(price_research, attrs), do: create_changeset(price_research, attrs)
end
