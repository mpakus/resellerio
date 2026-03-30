defmodule Reseller.Repo.Migrations.AllowProductImageVariantsPerPosition do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:product_images, [:product_id, :position])
    create unique_index(:product_images, [:product_id, :kind, :position])
  end
end
