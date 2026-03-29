defmodule Reseller.Accounts.ApiToken do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_tokens" do
    field :token_hash, :binary
    field :context, :string, default: "mobile"
    field :device_name, :string
    field :expires_at, :utc_datetime
    field :last_used_at, :utc_datetime

    belongs_to :user, Reseller.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def create_changeset(api_token, attrs) do
    api_token
    |> cast(attrs, [:token_hash, :context, :device_name, :expires_at, :last_used_at])
    |> validate_required([:token_hash, :context, :expires_at])
    |> unique_constraint(:token_hash)
  end
end
