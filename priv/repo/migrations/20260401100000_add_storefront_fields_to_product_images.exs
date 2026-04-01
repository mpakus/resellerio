defmodule Reseller.Repo.Migrations.AddStorefrontFieldsToProductImages do
  use Ecto.Migration

  def change do
    alter table(:product_images) do
      add :storefront_visible, :boolean, default: false, null: false
      add :storefront_position, :integer
    end

    create index(:product_images, [:product_id, :storefront_position],
             name: :product_images_storefront_position_index
           )
  end
end
