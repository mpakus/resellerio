defmodule Reseller.Repo.Migrations.CreateImports do
  use Ecto.Migration

  def change do
    create table(:imports) do
      add :status, :string, null: false, default: "queued"
      add :source_filename, :string, null: false
      add :source_storage_key, :string, null: false
      add :requested_at, :utc_datetime, null: false
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :total_products, :integer, null: false, default: 0
      add :imported_products, :integer, null: false, default: 0
      add :failed_products, :integer, null: false, default: 0
      add :error_message, :string
      add :failure_details, :map, null: false, default: %{}
      add :payload, :map, null: false, default: %{}
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:imports, [:user_id])
  end
end
