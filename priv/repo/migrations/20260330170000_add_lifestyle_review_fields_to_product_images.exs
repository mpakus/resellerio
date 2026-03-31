defmodule Reseller.Repo.Migrations.AddLifestyleReviewFieldsToProductImages do
  use Ecto.Migration

  def change do
    alter table(:product_images) do
      add :seller_approved, :boolean, default: false, null: false
      add :approved_at, :utc_datetime
    end
  end
end
