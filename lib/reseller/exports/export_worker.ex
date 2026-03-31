defmodule Reseller.Exports.ExportWorker do
  @moduledoc """
  Builds ZIP exports, uploads them to storage, and triggers notifications.
  """

  require Logger

  alias Reseller.Exports
  alias Reseller.Exports.Export
  alias Reseller.Exports.Notifier
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

    with {:ok, zip_binary} <- builder(opts).build_export(export, user, opts),
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
         {:ok, download_url} <- Exports.download_url(completed_export, opts),
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
        record_failure(export, reason)
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

  defp record_failure(%Export{} = export, reason) do
    Logger.error("Export #{export.id} failed: #{inspect(reason)}")

    case Exports.mark_failed(export, format_failure(reason)) do
      {:ok, _failed_export} ->
        :ok

      {:error, changeset} ->
        Logger.error(
          "Export #{export.id} failure could not be persisted: #{inspect(changeset.errors)}"
        )

        :ok
    end
  end

  defp format_failure({:image_download_failed, image_id, {:http_error, 404, body}}) do
    code_suffix =
      case storage_error_code(body) do
        nil -> ""
        code -> " #{code}"
      end

    "Export failed because product image ##{image_id} is missing from storage (HTTP 404#{code_suffix}). Re-upload the image and retry."
  end

  defp format_failure({:image_download_failed, image_id, {:http_error, status, _body}}) do
    "Export failed because product image ##{image_id} could not be downloaded from storage (HTTP #{status}). Check storage access and retry."
  end

  defp format_failure(
         {:image_download_failed, image_id,
          {:request_failed, %Req.TransportError{reason: reason}}}
       )
       when reason in [:timeout, :connect_timeout, :closed] do
    "Export failed because downloading product image ##{image_id} timed out. Retry the export."
  end

  defp format_failure({:image_download_failed, image_id, _reason}) do
    "Export failed because product image ##{image_id} could not be downloaded. Check storage access and retry."
  end

  defp format_failure({:zip_create_failed, reason}) do
    "Export failed while building the ZIP archive: #{inspect(reason)}"
  end

  defp format_failure(reason) do
    "Export failed: #{inspect(reason, printable_limit: 200, limit: 20)}"
  end

  defp storage_error_code(body) when is_binary(body) do
    case Regex.run(~r/<Code>([^<]+)<\/Code>/, body, capture: :all_but_first) do
      [code] -> code
      _other -> nil
    end
  end

  defp storage_error_code(_body), do: nil
end
