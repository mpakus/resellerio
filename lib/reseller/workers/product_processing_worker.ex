defmodule Reseller.Workers.ProductProcessingWorker do
  @moduledoc """
  Runs asynchronous processing for a finalized product.
  """

  alias Reseller.Catalog.Product
  alias Reseller.Catalog
  alias Reseller.Media
  alias Reseller.Media.ProductImage
  alias Reseller.Repo
  alias Reseller.Workers
  alias Reseller.Workers.ProductProcessingRun

  import Ecto.Query, warn: false

  @spec perform(pos_integer(), keyword()) :: :ok
  def perform(run_id, opts \\ []) when is_integer(run_id) do
    processor = Keyword.get(opts, :processor, Workers.processor(opts))

    case fetch_run(run_id) do
      nil ->
        :ok

      run ->
        run
        |> mark_running()
        |> process_run(processor, opts)
    end
  end

  defp fetch_run(run_id) do
    ProductProcessingRun
    |> Repo.get(run_id)
    |> case do
      nil -> nil
      run -> Repo.preload(run, product: [images: image_query()])
    end
  end

  defp mark_running(run) do
    {:ok, updated_run} =
      run
      |> ProductProcessingRun.update_changeset(%{
        "status" => "running",
        "step" => "prepare_images",
        "started_at" => DateTime.utc_now(),
        "payload" => run.payload || %{}
      })
      |> Repo.update()

    mark_uploaded_images_processing(updated_run.product)
    Repo.preload(updated_run, [product: [images: image_query()]], force: true)
  end

  defp process_run(run, processor, opts) do
    case processor.process(run.product, opts) do
      {:ok, %{step: step, payload: payload}} ->
        complete_run(run, step, payload)

      {:error, %{code: code, message: message, payload: payload}} ->
        fail_run(run, code, message, payload)

      {:error, reason} ->
        fail_run(run, "processor_error", inspect(reason), %{})
    end

    :ok
  end

  defp complete_run(run, step, payload) do
    run
    |> ProductProcessingRun.update_changeset(%{
      "status" => "completed",
      "step" => step,
      "finished_at" => DateTime.utc_now(),
      "payload" => payload
    })
    |> Repo.update!()
  end

  defp fail_run(run, code, message, payload) do
    {:ok, _count} = Media.mark_product_images_failed(run.product)
    {:ok, _product} = Catalog.mark_processing_failed(run.product)

    run
    |> ProductProcessingRun.update_changeset(%{
      "status" => "failed",
      "step" => run.step || "prepare_images",
      "finished_at" => DateTime.utc_now(),
      "error_code" => code,
      "error_message" => message,
      "payload" => payload
    })
    |> Repo.update!()
  end

  defp mark_uploaded_images_processing(%Product{id: product_id}) do
    ProductImage
    |> where([image], image.product_id == ^product_id and image.processing_status == "uploaded")
    |> Repo.update_all(set: [processing_status: "processing"])
  end

  defp image_query do
    from(image in ProductImage, order_by: [asc: image.position, asc: image.id])
  end
end
