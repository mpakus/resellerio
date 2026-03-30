defmodule Reseller.Imports do
  @moduledoc """
  Handles import record lifecycle and ZIP import orchestration.
  """

  import Ecto.Query, warn: false

  alias Reseller.Accounts.User
  alias Reseller.Imports.ArchiveImporter
  alias Reseller.Imports.Import
  alias Reseller.Imports.ImportRequest
  alias Reseller.Imports.ImportWorker
  alias Reseller.Imports.ZipParser
  alias Reseller.Media
  alias Reseller.Media.Storage
  alias Reseller.Repo

  def request_import_for_user(%User{} = user, attrs, opts \\ []) when is_map(attrs) do
    with {:ok, validated_attrs} <- ImportRequest.validated_attrs(attrs),
         {:ok, import_record} <- create_import(user, validated_attrs),
         {:ok, _upload} <- upload_archive(import_record, validated_attrs.archive_binary, opts),
         :ok <-
           enqueue_import(
             import_record,
             Keyword.put(opts, :archive_binary, validated_attrs.archive_binary)
           ) do
      {:ok, get_import!(import_record.id)}
    end
  end

  def get_import(id) when is_integer(id), do: Repo.get(Import, id)
  def get_import!(id) when is_integer(id), do: Repo.get!(Import, id)

  def get_import_for_user(%User{id: user_id}, id) do
    Import
    |> where([import_record], import_record.user_id == ^user_id and import_record.id == ^id)
    |> Repo.one()
  end

  def list_imports_for_user(%User{id: user_id}) do
    Import
    |> where([import_record], import_record.user_id == ^user_id)
    |> order_by([import_record], desc: import_record.inserted_at)
    |> Repo.all()
  end

  def mark_running(%Import{} = import_record) do
    import_record
    |> Import.update_changeset(%{
      "status" => "running",
      "started_at" => now(),
      "error_message" => nil
    })
    |> Repo.update!()
  end

  def mark_completed(%Import{} = import_record, summary) when is_map(summary) do
    import_record
    |> Import.update_changeset(%{
      "status" => "completed",
      "finished_at" => now(),
      "total_products" => Map.get(summary, :total_products, 0),
      "imported_products" => Map.get(summary, :imported_products, 0),
      "failed_products" => Map.get(summary, :failed_products, 0),
      "failure_details" => %{"items" => Map.get(summary, :failures, [])},
      "payload" => %{"created_product_ids" => Map.get(summary, :created_product_ids, [])},
      "error_message" => nil
    })
    |> Repo.update()
  end

  def mark_failed(%Import{} = import_record, error_message, attrs \\ %{})
      when is_binary(error_message) and is_map(attrs) do
    import_record
    |> Import.update_changeset(%{
      "status" => "failed",
      "finished_at" => now(),
      "error_message" => error_message,
      "total_products" => Map.get(attrs, :total_products, import_record.total_products || 0),
      "imported_products" =>
        Map.get(attrs, :imported_products, import_record.imported_products || 0),
      "failed_products" => Map.get(attrs, :failed_products, import_record.failed_products || 0),
      "failure_details" => Map.get(attrs, :failure_details, import_record.failure_details || %{}),
      "payload" => Map.get(attrs, :payload, import_record.payload || %{})
    })
    |> Repo.update()
  end

  def import_user!(%Import{user_id: user_id}), do: Repo.get!(User, user_id)

  def build_source_storage_key(%Import{id: import_id}, %User{id: user_id}) do
    "users/#{user_id}/imports/#{import_id}/source.zip"
  end

  def processing_mode(opts \\ []) do
    Keyword.get(opts, :mode, Application.fetch_env!(:reseller, __MODULE__)[:processing_mode])
  end

  def fetch_archive(%Import{} = import_record, opts \\ []) do
    case Keyword.get(opts, :archive_binary) do
      archive_binary when is_binary(archive_binary) ->
        {:ok, archive_binary}

      _other ->
        with {:ok, archive_url} <-
               Media.public_url_for_storage_key(import_record.source_storage_key, opts),
             {:ok, %{status: status, body: body}} <- download_request(opts).(archive_url),
             true <- status in 200..299 do
          {:ok, body}
        else
          false -> {:error, :archive_download_failed}
          {:error, reason} -> {:error, reason}
          {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
        end
    end
  end

  def run_archive_import(%Import{} = import_record, archive_binary, opts \\ [])
      when is_binary(archive_binary) do
    with {:ok, parsed_archive} <- ZipParser.parse_archive(archive_binary),
         {:ok, summary} <-
           ArchiveImporter.import_user_archive(import_user!(import_record), parsed_archive, opts) do
      {:ok, summary}
    end
  end

  defp create_import(%User{} = user, validated_attrs) do
    %Import{}
    |> Import.create_changeset(%{
      "status" => "queued",
      "source_filename" => validated_attrs.filename,
      "source_storage_key" => build_source_storage_key(%Import{id: 0}, user),
      "requested_at" => now()
    })
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
    |> case do
      {:ok, import_record} ->
        import_record
        |> Import.update_changeset(%{
          "source_storage_key" => build_source_storage_key(import_record, user)
        })
        |> Repo.update()

      error ->
        error
    end
  end

  defp upload_archive(%Import{} = import_record, archive_binary, opts) do
    Storage.upload_object(
      import_record.source_storage_key,
      archive_binary,
      Keyword.merge(
        [
          content_type: "application/zip",
          provider: Keyword.get(opts, :storage, Storage.provider())
        ],
        Keyword.take(opts, [:upload_request_fun, :request_time, :expires_in, :config])
      )
    )
  end

  defp enqueue_import(%Import{} = import_record, opts) do
    case processing_mode(opts) do
      :inline ->
        ImportWorker.perform(import_record.id, opts)
        :ok

      :async ->
        case Task.Supervisor.start_child(Reseller.Workers.TaskSupervisor, fn ->
               ImportWorker.perform(import_record.id, opts)
             end) do
          {:ok, _pid} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp download_request(opts) do
    Keyword.get(opts, :download_request_fun, fn archive_url -> Req.get(url: archive_url) end)
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
