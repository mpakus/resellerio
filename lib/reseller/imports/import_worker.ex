defmodule Reseller.Imports.ImportWorker do
  @moduledoc """
  Downloads stored ZIP archives and recreates products from them.
  """

  alias Reseller.Imports
  alias Reseller.Imports.Import

  def perform(import_id, opts \\ []) when is_integer(import_id) do
    case Imports.get_import(import_id) do
      nil ->
        :ok

      import_record ->
        import_record
        |> Imports.mark_running()
        |> process_import(opts)
    end
  end

  defp process_import(%Import{} = import_record, opts) do
    with {:ok, archive_binary} <- Imports.fetch_archive(import_record, opts),
         {:ok, summary} <- Imports.run_archive_import(import_record, archive_binary, opts),
         {:ok, _completed_import} <- Imports.mark_completed(import_record, summary) do
      :ok
    else
      {:error, reason} ->
        Imports.mark_failed(import_record, "Import failed: #{inspect(reason)}")
        :ok
    end
  end
end
