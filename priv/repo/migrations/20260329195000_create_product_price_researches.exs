defmodule Reseller.Repo.Migrations.CreateProductPriceResearches do
  use Ecto.Migration

  def change do
    create table(:product_price_researches) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "generated"
      add :provider, :string
      add :model, :string
      add :currency, :string, null: false, default: "USD"
      add :suggested_min_price, :decimal, precision: 12, scale: 2
      add :suggested_target_price, :decimal, precision: 12, scale: 2
      add :suggested_max_price, :decimal, precision: 12, scale: 2
      add :suggested_median_price, :decimal, precision: 12, scale: 2
      add :pricing_confidence, :float
      add :rationale_summary, :text
      add :market_signals, {:array, :string}, null: false, default: []
      add :comparable_results, :map, null: false, default: %{}
      add :raw_payload, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:product_price_researches, [:product_id])
  end
end
