defmodule Reseller.Exports.ExportWorker do
  @moduledoc """
  Builds ZIP exports, uploads them to storage, and triggers notifications.
  """

  alias Reseller.Exports
  alias Reseller.Exports.Export
  alias Reseller.Exports.Notifier
  alias Reseller.Media
  alias Reseller.Media.Storage

  @spec perform(pos_integer(), keyword()) :: :ok
  def perform(export_id, opts \\ []) when is_integer(export_id) do
    case Exports.get_export(export_id) do
      nil ->
        :ok

      export ->
        export
        |> Exports.mark_running()
        |> build_and_upload(opts)
    end
  end

  defp build_and_upload(%Export{} = export, opts) do
    user = Exports.export_user!(export)

    with {:ok, zip_binary} <- builder(opts).build_user_export(user, opts),
         storage_key = Exports.build_storage_key(export, user),
         {:ok, _upload} <-
           Storage.upload_object(
             storage_key,
             zip_binary,
             Keyword.merge(
               [
                 content_type: "application/zip",
                 provider: Keyword.get(opts, :storage, Storage.provider())
               ],
               Keyword.take(opts, [:upload_request_fun, :request_time, :expires_in, :config])
             )
           ),
         {:ok, completed_export} <- Exports.mark_completed(export, storage_key, opts),
         {:ok, download_url} <- Media.public_url_for_storage_key(storage_key, opts),
         {:ok, _notification} <-
           Notifier.deliver_export_ready(
             user,
             completed_export,
             download_url,
             notifier_opts(opts)
           ) do
      :ok
    else
      {:error, reason} ->
        Exports.mark_failed(export, "Export failed: #{inspect(reason)}")
        :ok
    end
  end

  defp builder(opts),
    do: Keyword.get(opts, :builder, Application.fetch_env!(:reseller, Reseller.Exports)[:builder])

  defp notifier_opts(opts) do
    opts
    |> Keyword.take([:notifier, :from_email])
    |> Keyword.put_new(:notifier, Notifier.notifier(opts))
  end
end
