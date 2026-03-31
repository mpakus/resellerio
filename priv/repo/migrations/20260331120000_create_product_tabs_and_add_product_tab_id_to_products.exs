defmodule Reseller.Repo.Migrations.CreateProductTabsAndAddProductTabIdToProducts do
  use Ecto.Migration

  def change do
    create table(:product_tabs) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:product_tabs, [:user_id])
    create index(:product_tabs, [:user_id, :position])
    create unique_index(:product_tabs, [:user_id, :name])

    alter table(:products) do
      add :product_tab_id, references(:product_tabs, on_delete: :nilify_all)
    end

    create index(:products, [:product_tab_id])
    create index(:products, [:user_id, :product_tab_id])
  end
end
