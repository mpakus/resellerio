defmodule Reseller.Repo.Migrations.AddExportMetadataFields do
  use Ecto.Migration

  def change do
    alter table(:exports) do
      add :name, :string, null: false, default: "Products export"
      add :file_name, :string, null: false, default: "products-export.zip"
      add :filter_params, :map, null: false, default: %{}
      add :product_count, :integer, null: false, default: 0
    end
  end
end
