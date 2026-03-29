defmodule ResellerWeb.API.V1.MeController do
  use ResellerWeb, :controller

  def show(conn, _params) do
    user = conn.assigns.current_user

    json(conn, %{
      data: %{
        user: %{
          id: user.id,
          email: user.email,
          confirmed_at: user.confirmed_at && DateTime.to_iso8601(user.confirmed_at)
        }
      }
    })
  end
end
