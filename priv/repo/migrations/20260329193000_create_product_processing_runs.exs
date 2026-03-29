defmodule Reseller.Repo.Migrations.CreateProductProcessingRuns do
  use Ecto.Migration

  def change do
    create table(:product_processing_runs) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :step, :string, null: false
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :error_code, :string
      add :error_message, :text
      add :payload, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:product_processing_runs, [:product_id])
    create index(:product_processing_runs, [:product_id, :inserted_at])
    create index(:product_processing_runs, [:status])
  end
end
