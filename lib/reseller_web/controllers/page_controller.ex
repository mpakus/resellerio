defmodule ResellerWeb.PageController do
  use ResellerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
