defmodule Reseller.Repo.Migrations.CreateApiUsageEvents do
  use Ecto.Migration

  def change do
    create table(:api_usage_events) do
      add :user_id, references(:users, on_delete: :nilify_all), null: true
      add :product_id, references(:products, on_delete: :nilify_all), null: true
      add :provider, :string, null: false
      add :operation, :string, null: false
      add :model, :string
      add :status, :string, null: false
      add :http_status, :integer
      add :request_count, :integer, default: 1
      add :image_count, :integer, default: 0
      add :input_tokens, :integer
      add :output_tokens, :integer
      add :total_tokens, :integer
      add :cost_usd, :decimal, precision: 12, scale: 8
      add :duration_ms, :integer
      add :error_code, :string
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:api_usage_events, [:user_id])
    create index(:api_usage_events, [:product_id])
    create index(:api_usage_events, [:provider, :operation])
    create index(:api_usage_events, [:user_id, :inserted_at])
    create index(:api_usage_events, [:product_id, :inserted_at])
    create index(:api_usage_events, [:inserted_at])
  end
end
