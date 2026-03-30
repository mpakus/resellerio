defmodule Reseller.Repo.Migrations.CreateMarketplaceListings do
  use Ecto.Migration

  def change do
    create table(:marketplace_listings) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :marketplace, :string, null: false
      add :status, :string, null: false, default: "generated"
      add :generated_title, :string
      add :generated_description, :text
      add :generated_tags, {:array, :string}, null: false, default: []
      add :generated_price_suggestion, :decimal, precision: 12, scale: 2
      add :generation_version, :string
      add :compliance_warnings, {:array, :string}, null: false, default: []
      add :raw_payload, :map, null: false, default: %{}
      add :last_generated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:marketplace_listings, [:product_id, :marketplace])
  end
end
