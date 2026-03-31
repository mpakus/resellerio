defmodule Reseller.AI.LifestyleGenerationRunTest do
  use Reseller.DataCase, async: true

  alias Reseller.AI

  test "creates and lists lifestyle generation runs for a product" do
    user = user_fixture()
    product = product_fixture(user, %{"title" => "Structured coat"})

    assert {:ok, queued_run} =
             AI.create_product_lifestyle_generation_run(product, %{
               "status" => "queued",
               "step" => "queued",
               "scene_family" => "apparel",
               "prompt_version" => "v1",
               "requested_count" => 3,
               "completed_count" => 0,
               "payload" => %{"summary" => "Waiting to generate scenes."}
             })

    assert {:ok, completed_run} =
             AI.create_product_lifestyle_generation_run(product, %{
               "status" => "completed",
               "step" => "lifestyle_generated",
               "scene_family" => "apparel",
               "model" => "gemini-2.5-flash-image",
               "prompt_version" => "v1",
               "requested_count" => 3,
               "completed_count" => 3,
               "payload" => %{"summary" => "All requested scenes generated."}
             })

    assert [latest_run, older_run] = AI.list_product_lifestyle_generation_runs(product.id)
    assert latest_run.id == completed_run.id
    assert older_run.id == queued_run.id
    assert AI.latest_product_lifestyle_generation_run(product.id).id == completed_run.id
  end

  test "updates lifestyle generation runs with count validation" do
    user = user_fixture()
    product = product_fixture(user, %{"title" => "Scene-tracked lamp"})

    assert {:ok, run} =
             AI.create_product_lifestyle_generation_run(product, %{
               "status" => "running",
               "step" => "lifestyle_generating",
               "scene_family" => "furniture",
               "requested_count" => 2,
               "completed_count" => 0,
               "payload" => %{}
             })

    assert {:error, changeset} =
             AI.update_product_lifestyle_generation_run(run, %{
               "completed_count" => 3
             })

    assert "must be less than or equal to requested_count" in errors_on(changeset).completed_count

    assert {:ok, updated_run} =
             AI.update_product_lifestyle_generation_run(run, %{
               "status" => "partial",
               "step" => "lifestyle_partial",
               "completed_count" => 1,
               "error_code" => "one_scene_failed",
               "error_message" => "The desk scene timed out.",
               "finished_at" => DateTime.utc_now() |> DateTime.truncate(:second),
               "payload" => %{"summary" => "One of two scenes generated."}
             })

    assert updated_run.status == "partial"
    assert updated_run.step == "lifestyle_partial"
    assert updated_run.completed_count == 1
    assert updated_run.error_code == "one_scene_failed"
    assert updated_run.error_message == "The desk scene timed out."
  end
end
