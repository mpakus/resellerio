defmodule ResellerWeb.LiveUserAuth do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView

  use ResellerWeb, :verified_routes

  alias Reseller.Accounts

  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, assign(socket, :current_user, user_from_session(session))}
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    case user_from_session(session) do
      nil ->
        {:cont, assign(socket, :current_user, nil)}

      _user ->
        {:halt, redirect(socket, to: ~p"/app")}
    end
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case user_from_session(session) do
      nil ->
        {:halt, redirect(socket, to: ~p"/sign-in")}

      user ->
        {:cont, assign(socket, :current_user, user)}
    end
  end

  defp user_from_session(%{"user_id" => user_id}), do: Accounts.get_user(user_id)
  defp user_from_session(_session), do: nil
end
