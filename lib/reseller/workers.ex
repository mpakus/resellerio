defmodule Reseller.Workers do
  import Ecto.Query, warn: false

  alias Reseller.Catalog.Product
  alias Reseller.Repo
  alias Reseller.Workers.ProductProcessingRun
  alias Reseller.Workers.ProductProcessingWorker

  @spec start_product_processing(Product.t(), keyword()) ::
          {:ok, ProductProcessingRun.t()} | {:error, Ecto.Changeset.t() | term()}
  def start_product_processing(%Product{} = product, opts \\ []) do
    with {:ok, run} <- create_processing_run(product) do
      case enqueue_run(run, opts) do
        :ok -> {:ok, Repo.get!(ProductProcessingRun, run.id)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @spec list_product_processing_runs(pos_integer()) :: [ProductProcessingRun.t()]
  def list_product_processing_runs(product_id) when is_integer(product_id) do
    ProductProcessingRun
    |> where([run], run.product_id == ^product_id)
    |> order_by([run], desc: run.inserted_at, desc: run.id)
    |> Repo.all()
  end

  @spec latest_product_processing_run(pos_integer()) :: ProductProcessingRun.t() | nil
  def latest_product_processing_run(product_id) when is_integer(product_id) do
    ProductProcessingRun
    |> where([run], run.product_id == ^product_id)
    |> order_by([run], desc: run.inserted_at, desc: run.id)
    |> limit(1)
    |> Repo.one()
  end

  @spec processor(keyword()) :: module()
  def processor(opts \\ []) do
    Keyword.get(
      opts,
      :processor,
      Application.fetch_env!(:reseller, __MODULE__)[:product_processor]
    )
  end

  @spec processing_mode(keyword()) :: :async | :inline
  def processing_mode(opts \\ []) do
    Keyword.get(opts, :mode, Application.fetch_env!(:reseller, __MODULE__)[:processing_mode])
  end

  defp create_processing_run(%Product{} = product) do
    %ProductProcessingRun{}
    |> ProductProcessingRun.create_changeset(%{
      "status" => "queued",
      "step" => "queued",
      "payload" => %{}
    })
    |> Ecto.Changeset.put_assoc(:product, product)
    |> Repo.insert()
  end

  defp enqueue_run(%ProductProcessingRun{} = run, opts) do
    worker_opts = Keyword.put(opts, :processor, processor(opts))

    case processing_mode(opts) do
      :inline ->
        ProductProcessingWorker.perform(run.id, worker_opts)
        :ok

      :async ->
        case Task.Supervisor.start_child(Reseller.Workers.TaskSupervisor, fn ->
               ProductProcessingWorker.perform(run.id, worker_opts)
             end) do
          {:ok, _pid} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end
end
