defmodule Reseller.Metrics.ApiUsageEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @providers ~w(gemini serp_api photoroom)
  @statuses ~w(success error)

  schema "api_usage_events" do
    field :provider, :string
    field :operation, :string
    field :model, :string
    field :status, :string
    field :http_status, :integer
    field :request_count, :integer, default: 1
    field :image_count, :integer, default: 0
    field :input_tokens, :integer
    field :output_tokens, :integer
    field :total_tokens, :integer
    field :cost_usd, :decimal
    field :duration_ms, :integer
    field :error_code, :string
    field :metadata, :map, default: %{}

    belongs_to :user, Reseller.Accounts.User
    belongs_to :product, Reseller.Catalog.Product

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def providers, do: @providers
  def statuses, do: @statuses

  def create_changeset(event, attrs) do
    event
    |> cast(attrs, [
      :user_id,
      :product_id,
      :provider,
      :operation,
      :model,
      :status,
      :http_status,
      :request_count,
      :image_count,
      :input_tokens,
      :output_tokens,
      :total_tokens,
      :cost_usd,
      :duration_ms,
      :error_code,
      :metadata
    ])
    |> validate_required([:provider, :operation, :status])
    |> validate_inclusion(:provider, @providers)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:request_count, greater_than_or_equal_to: 0)
    |> validate_number(:image_count, greater_than_or_equal_to: 0)
  end

  def backpex_changeset(event, attrs, _metadata) do
    create_changeset(event, attrs)
  end
end
