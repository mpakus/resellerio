defmodule ResellerWeb.API.V1.RootController do
  use ResellerWeb, :controller

  alias ResellerWeb.API.V1.APISpec

  def show(conn, _params) do
    json(conn, %{data: APISpec.root_payload()})
  end
end
