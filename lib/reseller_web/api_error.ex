defmodule ResellerWeb.APIError do
  import Phoenix.Controller, only: [json: 2]
  import Plug.Conn, only: [put_status: 2]

  alias Ecto.Changeset
  alias Plug.Conn

  def validation(conn, %Changeset{} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{
        code: "validation_failed",
        detail: "Validation failed",
        status: 422,
        fields: translate_errors(changeset)
      }
    })
  end

  def unauthorized(conn, detail \\ "Unauthorized") do
    render(conn, :unauthorized, "unauthorized", detail)
  end

  def render(conn, status, code, detail) when is_atom(status) do
    conn
    |> put_status(status)
    |> json(%{
      error: %{
        code: code,
        detail: detail,
        status: Conn.Status.code(status)
      }
    })
  end

  defp translate_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
