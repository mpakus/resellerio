defmodule Reseller.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    create table(:products) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "draft"
      add :source, :string, null: false, default: "manual"
      add :title, :string
      add :brand, :string
      add :category, :string
      add :condition, :string
      add :color, :string
      add :size, :string
      add :material, :string
      add :price, :decimal, precision: 12, scale: 2
      add :cost, :decimal, precision: 12, scale: 2
      add :sku, :string
      add :notes, :text
      add :ai_summary, :text
      add :ai_confidence, :float
      add :sold_at, :utc_datetime
      add :archived_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:products, [:user_id])
    create index(:products, [:user_id, :status])
    create unique_index(:products, [:user_id, :sku], where: "sku IS NOT NULL")
  end
end
