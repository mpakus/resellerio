defmodule ResellerWeb.API.V1.MeController do
  use ResellerWeb, :controller

  alias Reseller.Accounts
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

  defp marketplace_params(%{"user" => user_params}) when is_map(user_params), do: user_params
  defp marketplace_params(params) when is_map(params), do: params
end
