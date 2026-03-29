defmodule ResellerWeb.API.V1.AuthController do
  use ResellerWeb, :controller

  alias Reseller.Accounts
  alias ResellerWeb.APIError

  def register(conn, params) do
    with {:ok, user} <- Accounts.register_user(params),
         {:ok, raw_token, api_token} <- Accounts.issue_api_token(user, params) do
      json(conn, %{data: token_response(user, raw_token, api_token.expires_at)})
    else
      {:error, %Ecto.Changeset{} = changeset} -> APIError.validation(conn, changeset)
    end
  end

  def login(conn, %{"email" => email, "password" => password} = params) do
    with {:ok, user} <- Accounts.authenticate_user(email, password),
         {:ok, raw_token, api_token} <- Accounts.issue_api_token(user, params) do
      json(conn, %{data: token_response(user, raw_token, api_token.expires_at)})
    else
      {:error, :invalid_credentials} ->
        APIError.unauthorized(conn, "Invalid email or password")
    end
  end

  def login(conn, _params) do
    APIError.render(conn, :bad_request, "invalid_request", "Email and password are required")
  end

  defp token_response(user, token, expires_at) do
    %{
      token: token,
      token_type: "Bearer",
      expires_at: DateTime.to_iso8601(expires_at),
      user: %{
        id: user.id,
        email: user.email,
        confirmed_at: user.confirmed_at && DateTime.to_iso8601(user.confirmed_at)
      }
    }
  end
end
