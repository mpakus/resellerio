defmodule ResellerWeb.SessionController do
  use ResellerWeb, :controller

  alias Reseller.Accounts
  alias ResellerWeb.BrowserAuth

  def create(conn, %{"session" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> BrowserAuth.log_in_user(user)
        |> put_flash(:info, "Welcome back.")
        |> redirect(to: ~p"/app")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/sign-in")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Email and password are required.")
    |> redirect(to: ~p"/sign-in")
  end

  def delete(conn, _params) do
    conn
    |> BrowserAuth.log_out_user()
    |> put_flash(:info, "Signed out.")
    |> redirect(to: ~p"/")
  end
end
