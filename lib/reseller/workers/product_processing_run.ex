defmodule Reseller.Workers.ProductProcessingRun do
  use Ecto.Schema
  import Ecto.Changeset

  schema "product_processing_runs" do
    field :status, :string
    field :step, :string
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :error_code, :string
    field :error_message, :string
    field :payload, :map, default: %{}

    belongs_to :product, Reseller.Catalog.Product

    timestamps(type: :utc_datetime)
  end

  def create_changeset(run, attrs) do
    run
    |> cast(attrs, [
      :status,
      :step,
      :started_at,
      :finished_at,
      :error_code,
      :error_message,
      :payload
    ])
    |> validate_required([:status, :step, :payload])
    |> validate_inclusion(:status, ~w(queued running completed failed))
    |> validate_length(:step, max: 80)
    |> validate_length(:error_code, max: 120)
  end

  def update_changeset(run, attrs), do: create_changeset(run, attrs)
end
