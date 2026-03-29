defmodule Reseller.Repo.Migrations.CreateProductDescriptionDrafts do
  use Ecto.Migration

  def change do
    create table(:product_description_drafts) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "generated"
      add :provider, :string
      add :model, :string
      add :suggested_title, :string
      add :short_description, :string
      add :long_description, :text
      add :key_features, {:array, :string}, null: false, default: []
      add :seo_keywords, {:array, :string}, null: false, default: []
      add :missing_details_warning, :string
      add :raw_payload, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:product_description_drafts, [:product_id])
  end
end
