defmodule ResellerWeb.API.V1.OpenAPIController do
  use ResellerWeb, :controller

  alias ResellerWeb.API.V1.APISpec

  def show(conn, _params) do
    json(conn, APISpec.openapi_document())
  end
end
