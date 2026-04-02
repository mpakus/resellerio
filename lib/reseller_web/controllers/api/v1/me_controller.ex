defmodule ResellerWeb.API.V1.MeController do
  use ResellerWeb, :controller

  alias Reseller.Accounts
  alias Reseller.Billing.Plans
  alias Reseller.Metrics
  alias ResellerWeb.API.V1.UserJSON
  alias ResellerWeb.APIError

  def show(conn, _params) do
    json(conn, %{data: UserJSON.response(conn.assigns.current_user)})
  end

  def update(conn, params) do
    current_user = conn.assigns.current_user

    case Accounts.update_user_marketplace_settings(current_user, marketplace_params(params)) do
      {:ok, user} ->
        json(conn, %{data: UserJSON.response(user)})

      {:error, %Ecto.Changeset{} = changeset} ->
        APIError.validation(conn, changeset)
    end
  end

  def usage(conn, _params) do
    user = conn.assigns.current_user
    usage = Metrics.monthly_usage_for_user(user.id)
    limits = Plans.limits_for_user(user)

    json(conn, %{
      data: %{
        usage: %{
          ai_drafts: usage.ai_drafts,
          background_removals: usage.background_removals,
          lifestyle: usage.lifestyle,
          price_research: usage.price_research
        },
        limits: %{
          ai_drafts: limits.ai_drafts,
          background_removals: limits.background_removals,
          lifestyle: limits.lifestyle,
          price_research: limits.price_research
        },
        addon_credits: user.addon_credits || %{}
      }
    })
  end

  defp marketplace_params(%{"user" => user_params}) when is_map(user_params), do: user_params
  defp marketplace_params(params) when is_map(params), do: params
end
