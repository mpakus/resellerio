defmodule Reseller.Repo.Migrations.AddSelectedMarketplacesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :selected_marketplaces, {:array, :string},
        null: false,
        default: ["ebay", "depop", "poshmark"]
    end
  end
end
