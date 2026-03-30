defmodule Reseller.Repo.Migrations.AddTagsToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :tags, {:array, :string}, default: [], null: false
    end
  end
end
