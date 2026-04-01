defmodule ResellerWeb.RegistrationController do
  use ResellerWeb, :controller

  alias Reseller.Accounts
  alias ResellerWeb.BrowserAuth

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> BrowserAuth.log_in_user(user)
        |> put_flash(:info, "Account created. Welcome to ResellerIO Web.")
        |> redirect(to: ~p"/app")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Could not create your account. Check your email and password.")
        |> redirect(to: ~p"/sign-up")
    end
  end
end
