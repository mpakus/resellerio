defmodule Reseller.Repo.Migrations.AddLifestyleGenerationTracking do
  use Ecto.Migration

  def change do
    create table(:product_lifestyle_generation_runs) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :step, :string, null: false
      add :scene_family, :string
      add :model, :string
      add :prompt_version, :string
      add :requested_count, :integer, null: false, default: 0
      add :completed_count, :integer, null: false, default: 0
      add :error_code, :string
      add :error_message, :text
      add :payload, :map, null: false, default: %{}
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:product_lifestyle_generation_runs, [:product_id])
    create index(:product_lifestyle_generation_runs, [:product_id, :inserted_at])
    create index(:product_lifestyle_generation_runs, [:status])

    alter table(:product_images) do
      add :lifestyle_generation_run_id,
          references(:product_lifestyle_generation_runs, on_delete: :nilify_all)

      add :scene_key, :string
      add :variant_index, :integer
      add :source_image_ids, {:array, :integer}, null: false, default: []
    end

    create index(:product_images, [:lifestyle_generation_run_id])

    create unique_index(
             :product_images,
             [:lifestyle_generation_run_id, :scene_key, :variant_index],
             name: :product_images_lifestyle_generation_variant_index,
             where: "lifestyle_generation_run_id IS NOT NULL"
           )
  end
end
