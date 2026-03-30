defmodule Reseller.Exports.Export do
  use Ecto.Schema
  import Ecto.Changeset

  schema "exports" do
    field :status, :string, default: "queued"
    field :storage_key, :string
    field :expires_at, :utc_datetime
    field :requested_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :error_message, :string

    belongs_to :user, Reseller.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def create_changeset(export, attrs) do
    export
    |> cast(attrs, [
      :status,
      :storage_key,
      :expires_at,
      :requested_at,
      :completed_at,
      :error_message
    ])
    |> validate_required([:status, :requested_at])
    |> validate_inclusion(:status, ~w(queued running completed failed))
    |> validate_length(:storage_key, max: 512)
    |> validate_length(:error_message, max: 500)
  end

  def update_changeset(export, attrs), do: create_changeset(export, attrs)
end
