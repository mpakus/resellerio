defmodule ResellerWeb.Admin.ApiUsageEventLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: Reseller.Metrics.ApiUsageEvent,
      repo: Reseller.Repo,
      create_changeset: &Reseller.Metrics.ApiUsageEvent.backpex_changeset/3,
      update_changeset: &Reseller.Metrics.ApiUsageEvent.backpex_changeset/3
    ]

  alias Backpex.Fields
  alias Reseller.Accounts

  @impl Backpex.LiveResource
  def singular_name, do: "API Usage Event"

  @impl Backpex.LiveResource
  def plural_name, do: "API Usage Events"

  @impl Backpex.LiveResource
  def fields do
    [
      inserted_at: %{
        module: Fields.DateTime,
        label: "When",
        only: [:index, :show]
      },
      provider: %{
        module: Fields.Text,
        label: "Provider",
        searchable: true
      },
      operation: %{
        module: Fields.Text,
        label: "Operation",
        searchable: true
      },
      model: %{
        module: Fields.Text,
        label: "Model",
        only: [:show]
      },
      status: %{
        module: Fields.Text,
        label: "Status"
      },
      http_status: %{
        module: Fields.Number,
        label: "HTTP",
        only: [:show]
      },
      image_count: %{
        module: Fields.Number,
        label: "Images",
        only: [:show]
      },
      input_tokens: %{
        module: Fields.Number,
        label: "In Tokens",
        only: [:show]
      },
      output_tokens: %{
        module: Fields.Number,
        label: "Out Tokens",
        only: [:show]
      },
      total_tokens: %{
        module: Fields.Number,
        label: "Tokens"
      },
      cost_usd: %{
        module: Fields.Text,
        label: "Cost (USD)"
      },
      duration_ms: %{
        module: Fields.Number,
        label: "Duration (ms)",
        only: [:show]
      },
      error_code: %{
        module: Fields.Text,
        label: "Error",
        only: [:show]
      }
    ]
  end

  @impl Backpex.LiveResource
  def can?(assigns, action, _item) do
    Accounts.admin?(assigns.current_user) and action in [:index, :show]
  end

  @impl Backpex.LiveResource
  def layout(_assigns), do: {ResellerWeb.Layouts, :admin}
end
