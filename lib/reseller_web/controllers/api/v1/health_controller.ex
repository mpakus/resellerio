defmodule ResellerWeb.API.V1.HealthController do
  use ResellerWeb, :controller

  def show(conn, _params) do
    json(conn, %{
      data: %{
        name: "resellerio",
        status: "ok",
        version: app_version()
      }
    })
  end

  defp app_version do
    :reseller
    |> Application.spec(:vsn)
    |> to_string()
  end
end
