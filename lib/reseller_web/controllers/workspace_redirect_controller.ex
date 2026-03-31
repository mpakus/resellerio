defmodule ResellerWeb.WorkspaceRedirectController do
  use ResellerWeb, :controller

  def listings(conn, _params) do
    conn
    |> put_flash(:info, "Listings moved to Products.")
    |> redirect(to: ~p"/app/products")
  end
end
