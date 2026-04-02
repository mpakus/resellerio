defmodule ResellerWeb.API.V1.UserJSON do
  alias Reseller.Accounts
  alias Reseller.Accounts.User
  alias Reseller.Marketplaces

  def response(%User{} = user) do
    %{
      user: user_json(user),
      supported_marketplaces:
        Enum.map(Marketplaces.catalog(), fn marketplace ->
          %{
            id: marketplace.id,
            label: marketplace.label
          }
        end)
    }
  end

  defp user_json(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      confirmed_at: user.confirmed_at && DateTime.to_iso8601(user.confirmed_at),
      selected_marketplaces: Accounts.selected_marketplaces(user),
      plan: user.plan,
      plan_status: user.plan_status,
      plan_period: user.plan_period,
      plan_expires_at: user.plan_expires_at && DateTime.to_iso8601(user.plan_expires_at),
      trial_ends_at: user.trial_ends_at && DateTime.to_iso8601(user.trial_ends_at),
      addon_credits: user.addon_credits || %{}
    }
  end
end
