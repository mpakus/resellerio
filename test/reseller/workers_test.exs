defmodule Reseller.WorkersTest do
  use Reseller.DataCase, async: true

  alias Reseller.Catalog
  alias Reseller.Workers

  test "start_product_processing/2 creates and completes a processing run inline" do
    user = user_fixture()

    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Nike sneakers"},
        [%{"filename" => "shoe-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    {:ok, %{product: finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    [run] = Workers.list_product_processing_runs(finalized_product.id)

    assert run.status == "completed"
    assert run.step == "awaiting_ai"
    assert run.payload["processor"] == "fake"

    refreshed_product = Catalog.get_product_for_user(user, product.id)
    assert Enum.all?(refreshed_product.images, &(&1.processing_status == "processing"))
    assert refreshed_product.processing_runs |> List.first() |> Map.get(:id) == run.id

    product_id = product.id
    assert_received {:product_processor_called, ^product_id, _opts}
  end

  test "start_product_processing/2 records processor failures" do
    user = user_fixture()

    {:ok, %{product: product}} =
      Catalog.create_product_for_user(
        user,
        %{"title" => "Nike sneakers"},
        [%{"filename" => "shoe-1.jpg", "content_type" => "image/jpeg", "byte_size" => 123_000}],
        storage: Reseller.Support.Fakes.MediaStorage
      )

    [image] = product.images

    {:ok, %{product: finalized_product}} =
      Catalog.finalize_product_uploads_for_user(user, product.id, [
        %{"id" => image.id, "checksum" => "abc123", "width" => 1200, "height" => 1600}
      ])

    assert {:ok, _failed_run} =
             Workers.start_product_processing(finalized_product,
               processor: Reseller.Support.Fakes.ProductProcessor,
               processor_result:
                 {:error,
                  %{code: "processor_failed", message: "AI service unavailable", payload: %{}}}
             )

    failed_run = Workers.latest_product_processing_run(finalized_product.id)

    assert failed_run.status == "failed"
    assert failed_run.error_code == "processor_failed"
    assert failed_run.error_message == "AI service unavailable"
  end
end
