defmodule ResellerWeb.BrowserAuth do
  import Plug.Conn

  alias Reseller.Accounts
  alias Reseller.Accounts.User

  def init(action), do: action

  def call(conn, :fetch_current_user), do: fetch_current_user(conn, [])
  def call(conn, :ensure_admin), do: ensure_admin(conn, [])
  def call(conn, _opts), do: conn

  def fetch_current_user(conn, _opts) do
    user =
      conn
      |> get_session(:user_id)
      |> case do
        nil -> nil
        user_id -> Accounts.get_user(user_id)
      end

    assign(conn, :current_user, user)
  end

  def log_in_user(conn, %User{} = user) do
    conn
    |> configure_session(renew: true)
    |> put_session(:user_id, user.id)
  end

  def log_out_user(conn) do
    configure_session(conn, drop: true)
  end

  def ensure_admin(conn, _opts) do
    case conn.assigns[:current_user] do
      %User{} = user ->
        if Accounts.admin?(user) do
          conn
        else
          conn
          |> Phoenix.Controller.put_flash(:error, "Admin access required.")
          |> Phoenix.Controller.redirect(to: "/app")
          |> halt()
        end

      _ ->
        conn
        |> Phoenix.Controller.redirect(to: "/sign-in")
        |> halt()
    end
  end
end
