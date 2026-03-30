defmodule Reseller.Exports do
  @moduledoc """
  Handles export record lifecycle and background generation orchestration.
  """

  import Ecto.Query, warn: false

  alias Reseller.Accounts.User
  alias Reseller.Exports.Export
  alias Reseller.Exports.ExportWorker
  alias Reseller.Repo

  @spec request_export_for_user(User.t(), keyword()) ::
          {:ok, Export.t()} | {:error, Ecto.Changeset.t() | term()}
  def request_export_for_user(%User{} = user, opts \\ []) do
    with {:ok, export} <- create_export(user),
         :ok <- enqueue_export(export, opts) do
      {:ok, get_export!(export.id)}
    end
  end

  @spec get_export(pos_integer()) :: Export.t() | nil
  def get_export(id) when is_integer(id), do: Repo.get(Export, id)

  @spec get_export!(pos_integer()) :: Export.t()
  def get_export!(id) when is_integer(id), do: Repo.get!(Export, id)

  @spec get_export_for_user(User.t(), term()) :: Export.t() | nil
  def get_export_for_user(%User{id: user_id}, id) do
    Export
    |> where([export], export.user_id == ^user_id and export.id == ^id)
    |> Repo.one()
  end

  @spec list_exports_for_user(User.t()) :: [Export.t()]
  def list_exports_for_user(%User{id: user_id}) do
    Export
    |> where([export], export.user_id == ^user_id)
    |> order_by([export], desc: export.inserted_at)
    |> Repo.all()
  end

  @spec mark_running(Export.t()) :: Export.t()
  def mark_running(%Export{} = export) do
    export
    |> Export.update_changeset(%{"status" => "running"})
    |> Repo.update!()
  end

  @spec mark_completed(Export.t(), String.t(), keyword()) ::
          {:ok, Export.t()} | {:error, Ecto.Changeset.t()}
  def mark_completed(%Export{} = export, storage_key, opts \\ []) do
    ttl_days =
      Keyword.get(
        opts,
        :ttl_days,
        Application.fetch_env!(:reseller, __MODULE__)[:export_ttl_days]
      )

    expires_at =
      DateTime.utc_now() |> DateTime.add(ttl_days * 86_400, :second) |> DateTime.truncate(:second)

    export
    |> Export.update_changeset(%{
      "status" => "completed",
      "storage_key" => storage_key,
      "expires_at" => expires_at,
      "completed_at" => DateTime.utc_now() |> DateTime.truncate(:second),
      "error_message" => nil
    })
    |> Repo.update()
  end

  @spec mark_failed(Export.t(), String.t()) :: {:ok, Export.t()} | {:error, Ecto.Changeset.t()}
  def mark_failed(%Export{} = export, error_message) do
    export
    |> Export.update_changeset(%{
      "status" => "failed",
      "error_message" => error_message
    })
    |> Repo.update()
  end

  @spec export_user!(Export.t()) :: User.t()
  def export_user!(%Export{user_id: user_id}), do: Repo.get!(User, user_id)

  @spec build_storage_key(Export.t(), User.t()) :: String.t()
  def build_storage_key(%Export{id: export_id}, %User{id: user_id}) do
    "users/#{user_id}/exports/#{export_id}.zip"
  end

  @spec processing_mode(keyword()) :: :async | :inline
  def processing_mode(opts \\ []) do
    Keyword.get(opts, :mode, Application.fetch_env!(:reseller, __MODULE__)[:processing_mode])
  end

  defp create_export(%User{} = user) do
    %Export{}
    |> Export.create_changeset(%{
      "status" => "queued",
      "requested_at" => DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Ecto.Changeset.put_assoc(:user, user)
    |> Repo.insert()
  end

  defp enqueue_export(%Export{} = export, opts) do
    case processing_mode(opts) do
      :inline ->
        ExportWorker.perform(export.id, opts)
        :ok

      :async ->
        case Task.Supervisor.start_child(Reseller.Workers.TaskSupervisor, fn ->
               ExportWorker.perform(export.id, opts)
             end) do
          {:ok, _pid} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
