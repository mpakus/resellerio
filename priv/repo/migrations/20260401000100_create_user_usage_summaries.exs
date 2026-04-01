defmodule Reseller.Repo.Migrations.CreateUserUsageSummaries do
  use Ecto.Migration

  def change do
    create table(:user_usage_summaries) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :gemini_calls, :integer, default: 0
      add :gemini_tokens, :integer, default: 0
      add :gemini_images, :integer, default: 0
      add :serp_api_calls, :integer, default: 0
      add :photoroom_calls, :integer, default: 0
      add :total_cost_usd, :decimal, precision: 12, scale: 4

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_usage_summaries, [:user_id, :date])
  end
end
