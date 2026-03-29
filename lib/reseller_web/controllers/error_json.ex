defmodule ResellerWeb.ErrorJSON do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on JSON requests.

  See config/config.exs.
  """

  def render(template, _assigns) do
    detail = Phoenix.Controller.status_message_from_template(template)
    status = status_code(template)

    %{
      error: %{
        code: error_code(detail),
        detail: detail,
        status: status
      }
    }
  end

  defp status_code(template) do
    template
    |> String.trim_trailing(".json")
    |> String.to_integer()
  end

  defp error_code(detail) do
    detail
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "_")
    |> String.trim("_")
  end
end
