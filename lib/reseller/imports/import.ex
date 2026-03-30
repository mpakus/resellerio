defmodule Reseller.Imports.Import do
  use Ecto.Schema
  import Ecto.Changeset

  schema "imports" do
    field :status, :string, default: "queued"
    field :source_filename, :string
    field :source_storage_key, :string
    field :requested_at, :utc_datetime
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :total_products, :integer, default: 0
    field :imported_products, :integer, default: 0
    field :failed_products, :integer, default: 0
    field :error_message, :string
    field :failure_details, :map, default: %{}
    field :payload, :map, default: %{}

    belongs_to :user, Reseller.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def create_changeset(import_record, attrs) do
    import_record
    |> cast(attrs, [
      :status,
      :source_filename,
      :source_storage_key,
      :requested_at,
      :started_at,
      :finished_at,
      :total_products,
      :imported_products,
      :failed_products,
      :error_message,
      :failure_details,
      :payload
    ])
    |> validate_required([:status, :source_filename, :source_storage_key, :requested_at])
    |> validate_inclusion(:status, ~w(queued running completed failed))
    |> validate_length(:source_filename, max: 255)
    |> validate_length(:source_storage_key, max: 512)
    |> validate_length(:error_message, max: 500)
    |> validate_number(:total_products, greater_than_or_equal_to: 0)
    |> validate_number(:imported_products, greater_than_or_equal_to: 0)
    |> validate_number(:failed_products, greater_than_or_equal_to: 0)
  end

  def update_changeset(import_record, attrs), do: create_changeset(import_record, attrs)
end
