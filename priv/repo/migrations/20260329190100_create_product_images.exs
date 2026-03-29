defmodule Reseller.Repo.Migrations.CreateProductImages do
  use Ecto.Migration

  def change do
    create table(:product_images) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :kind, :string, null: false, default: "original"
      add :position, :integer, null: false
      add :storage_key, :string, null: false
      add :content_type, :string, null: false
      add :width, :integer
      add :height, :integer
      add :byte_size, :integer
      add :checksum, :string
      add :background_style, :string
      add :processing_status, :string, null: false, default: "pending_upload"
      add :original_filename, :string

      timestamps(type: :utc_datetime)
    end

    create index(:product_images, [:product_id])
    create unique_index(:product_images, [:product_id, :position])
    create unique_index(:product_images, [:storage_key])
  end
end
