defmodule Reseller.Exports.Notifiers.Email do
  @moduledoc """
  Sends export-ready emails through Swoosh.
  """

  import Swoosh.Email

  alias Reseller.Exports.Export
  alias Reseller.Mailer

  @behaviour Reseller.Exports.Notifier

  @impl true
  def deliver_export_ready(user, %Export{} = export, download_url, opts \\ []) do
    from_email =
      Keyword.get(
        opts,
        :from_email,
        Application.fetch_env!(:reseller, Reseller.Exports)[:from_email]
      )

    email =
      new()
      |> to(user.email)
      |> from(from_email)
      |> subject("Your reseller export is ready")
      |> text_body("""
      Your export ##{export.id} is ready.

      Download: #{download_url}
      Expires at: #{DateTime.to_iso8601(export.expires_at)}
      """)

    case Mailer.deliver(email) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
