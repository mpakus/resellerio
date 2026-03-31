defmodule ResellerWeb.Plugs.APIAuth do
  import Plug.Conn

  alias Reseller.Accounts
  alias ResellerWeb.APIError

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- bearer_token(conn),
         %Reseller.Accounts.User{} = user <- Accounts.get_user_by_api_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> APIError.unauthorized("Missing or invalid bearer token")
        |> halt()
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      [header | _rest] when is_binary(header) ->
        case String.split(String.trim(header), ~r/\s+/, parts: 2) do
          [scheme, token] when token != "" ->
            if String.downcase(scheme) == "bearer" do
              {:ok, token}
            else
              :error
            end

          _other ->
            :error
        end

      _other ->
        :error
    end
  end
end
