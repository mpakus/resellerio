defmodule ResellerWeb.Admin.RedirectController do
  use ResellerWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: "/admin/users/")
  end
end
