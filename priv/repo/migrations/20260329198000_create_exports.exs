defmodule Reseller.Repo.Migrations.CreateExports do
  use Ecto.Migration

  def change do
    create table(:exports) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "queued"
      add :storage_key, :string
      add :expires_at, :utc_datetime
      add :requested_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :error_message, :string

      timestamps(type: :utc_datetime)
    end

    create index(:exports, [:user_id])
  end
end
