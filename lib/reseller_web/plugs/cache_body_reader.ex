defmodule ResellerWeb.CacheBodyReader do
  @moduledoc """
  A custom Plug body reader that caches the raw request body in `conn.assigns[:raw_body]`
  before it is consumed by `Plug.Parsers`. This is needed for webhook signature verification.
  """

  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = update_in(conn.assigns[:raw_body], fn existing -> (existing || "") <> body end)
    {:ok, body, conn}
  end
end
