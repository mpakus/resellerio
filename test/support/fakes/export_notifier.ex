defmodule Reseller.Support.Fakes.ExportNotifier do
  @behaviour Reseller.Exports.Notifier

  @impl true
  def deliver_export_ready(user, export, download_url, _opts) do
    send(self(), {:export_notifier_called, user.email, export.id, download_url})
    {:ok, :delivered}
  end
end
