defmodule Reseller.Workers do
  import Ecto.Query, warn: false

  alias Reseller.AI
  alias Reseller.Catalog.Product
  alias Reseller.Repo
  alias Reseller.Workers.LifestyleImageGenerator
  alias Reseller.Workers.ProductProcessingRun
  alias Reseller.Workers.ProductProcessingWorker

  @spec start_product_processing(Product.t(), keyword()) ::
          {:ok, ProductProcessingRun.t()} | {:error, Ecto.Changeset.t() | term()}
  def start_product_processing(%Product{} = product, opts \\ []) do
    with :ok <- check_processing_limit(product, opts),
         {:ok, run} <- create_processing_run(product) do
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

  @spec start_product_lifestyle_generation(Product.t(), keyword()) ::
          {:ok, Reseller.AI.ProductLifestyleGenerationRun.t() | nil}
          | {:error, Ecto.Changeset.t() | term()}
  def start_product_lifestyle_generation(%Product{} = product, opts \\ []) do
    worker_opts = Keyword.put(opts, :lifestyle_generation_enabled, true)
    latest_run_id = latest_lifestyle_run_id(product.id)

    with {:ok, _prepared} <- LifestyleImageGenerator.prepare(product, worker_opts),
         :ok <- enqueue_lifestyle_generation(product, worker_opts) do
      {:ok, await_new_lifestyle_run(product.id, latest_run_id)}
    end
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

  defp enqueue_lifestyle_generation(%Product{} = product, opts) do
    case processing_mode(opts) do
      :inline ->
        LifestyleImageGenerator.generate(product, opts)
        :ok

      :async ->
        case Task.Supervisor.start_child(Reseller.Workers.TaskSupervisor, fn ->
               LifestyleImageGenerator.generate(product, opts)
             end) do
          {:ok, _pid} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp latest_lifestyle_run_id(product_id) do
    case AI.latest_product_lifestyle_generation_run(product_id) do
      nil -> nil
      run -> run.id
    end
  end

  defp await_new_lifestyle_run(product_id, previous_run_id, attempts \\ 12)

  defp await_new_lifestyle_run(product_id, _previous_run_id, 0) do
    AI.latest_product_lifestyle_generation_run(product_id)
  end

  defp await_new_lifestyle_run(product_id, previous_run_id, attempts) do
    case AI.latest_product_lifestyle_generation_run(product_id) do
      nil ->
        Process.sleep(25)
        await_new_lifestyle_run(product_id, previous_run_id, attempts - 1)

      %{id: ^previous_run_id} ->
        Process.sleep(25)
        await_new_lifestyle_run(product_id, previous_run_id, attempts - 1)

      run ->
        run
    end
  end

  defp check_processing_limit(%Product{} = product, opts) do
    if Keyword.get(opts, :skip_limit_check, false) do
      :ok
    else
      case Reseller.Metrics.check_limit(product.user_id) do
        :ok -> :ok
        {:error, :limit_exceeded, details} -> {:error, {:limit_exceeded, details}}
      end
    end
  end
end
