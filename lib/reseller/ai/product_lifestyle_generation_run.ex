defmodule Reseller.AI.ProductLifestyleGenerationRun do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(queued running completed partial failed)

  schema "product_lifestyle_generation_runs" do
    field :status, :string
    field :step, :string
    field :scene_family, :string
    field :model, :string
    field :prompt_version, :string
    field :requested_count, :integer, default: 0
    field :completed_count, :integer, default: 0
    field :error_code, :string
    field :error_message, :string
    field :payload, :map, default: %{}
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime

    belongs_to :product, Reseller.Catalog.Product

    has_many :generated_images, Reseller.Media.ProductImage,
      foreign_key: :lifestyle_generation_run_id

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def create_changeset(run, attrs) do
    run
    |> cast(attrs, [
      :status,
      :step,
      :scene_family,
      :model,
      :prompt_version,
      :requested_count,
      :completed_count,
      :error_code,
      :error_message,
      :payload,
      :started_at,
      :finished_at
    ])
    |> validate_required([:status, :step, :requested_count, :completed_count, :payload])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:step, max: 80)
    |> validate_length(:scene_family, max: 120)
    |> validate_length(:model, max: 120)
    |> validate_length(:prompt_version, max: 80)
    |> validate_length(:error_code, max: 120)
    |> validate_number(:requested_count, greater_than_or_equal_to: 0)
    |> validate_number(:completed_count, greater_than_or_equal_to: 0)
    |> validate_completed_count()
  end

  def update_changeset(run, attrs), do: create_changeset(run, attrs)

  defp validate_completed_count(changeset) do
    requested_count = get_field(changeset, :requested_count) || 0
    completed_count = get_field(changeset, :completed_count) || 0

    if completed_count <= requested_count do
      changeset
    else
      add_error(changeset, :completed_count, "must be less than or equal to requested_count")
    end
  end
end
