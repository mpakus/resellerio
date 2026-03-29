defmodule ResellerWeb.Plugs.APIAuth do
  import Plug.Conn

  alias Reseller.Accounts
  alias ResellerWeb.APIError

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         %Reseller.Accounts.User{} = user <- Accounts.get_user_by_api_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> APIError.unauthorized("Missing or invalid bearer token")
        |> halt()
    end
  end
end
