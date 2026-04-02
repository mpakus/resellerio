defmodule Reseller.Repo.Migrations.AddSubscriptionFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :plan, :string, default: "free", null: false
      add :plan_status, :string, default: "free", null: false
      add :plan_period, :string
      add :plan_expires_at, :utc_datetime
      add :trial_ends_at, :utc_datetime
      add :ls_subscription_id, :string
      add :ls_customer_id, :string
      add :ls_variant_id, :string
      add :addon_credits, :map, default: %{}
      add :subscription_reminder_7d_sent_at, :utc_datetime
      add :subscription_reminder_2d_sent_at, :utc_datetime
    end

    create index(:users, [:ls_subscription_id])
    create index(:users, [:ls_customer_id])
    create index(:users, [:plan_status])
    create index(:users, [:plan_expires_at])
  end
end
