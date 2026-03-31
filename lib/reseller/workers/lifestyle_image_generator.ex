defmodule Reseller.Workers.LifestyleImageGenerator do
  @moduledoc """
  Generates optional lifestyle preview images as the final product-processing step.
  """

  alias Reseller.AI
  alias Reseller.AI.GeneratedImage
  alias Reseller.AI.LifestylePromptBuilder
  alias Reseller.Catalog.Product
  alias Reseller.Media
  alias Reseller.Media.Storage

  @spec generate(Product.t(), keyword()) :: map()
  def generate(%Product{} = product, opts \\ []) do
    if AI.lifestyle_generation_enabled?(opts) do
      do_generate(product, opts)
    else
      skipped_payload("disabled")
    end
  end

  @spec prepare(Product.t(), keyword()) ::
          {:ok, %{inputs: [map()], source_images: [struct()], scene_requests: [map()]}}
          | {:error, term()}
  def prepare(%Product{} = product, opts \\ []) do
    with {:ok, %{inputs: inputs, source_images: source_images}} <-
           Media.lifestyle_generation_inputs_for_product(product, opts),
         scene_requests when scene_requests != [] <- build_scene_requests(product, opts) do
      {:ok,
       %{
         inputs: inputs,
         source_images: source_images,
         scene_requests: scene_requests
       }}
    else
      [] -> {:error, :no_scene_requests}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_generate(%Product{} = product, opts) do
    with {:ok, %{inputs: inputs, source_images: source_images, scene_requests: scene_requests}} <-
           prepare(product, opts),
         {:ok, run} <- create_run(product, scene_requests, source_images),
         {:ok, running_run} <- mark_running(run, scene_requests, source_images),
         {scene_results, model} <-
           generate_scene_requests(
             running_run,
             product,
             scene_requests,
             inputs,
             source_images,
             opts
           ),
         {:ok, finished_run} <- finish_run(running_run, scene_results, model, source_images) do
      generation_payload(finished_run, scene_results, source_images)
    else
      {:error, :no_lifestyle_images} ->
        skipped_payload("no_eligible_images")

      {:error, :no_scene_requests} ->
        skipped_payload("no_scene_requests")

      {:error, reason} ->
        failed_payload(reason)
    end
  end

  defp build_scene_requests(%Product{} = product, opts) do
    product
    |> lifestyle_prompt_attrs()
    |> LifestylePromptBuilder.build(Keyword.take(opts, [:scene_count, :aspect_ratio]))
    |> maybe_filter_scene_requests(opts)
  end

  defp lifestyle_prompt_attrs(%Product{} = product) do
    %{
      "title" => product.title,
      "brand" => product.brand,
      "category" => product.category,
      "condition" => product.condition,
      "color" => product.color,
      "material" => product.material,
      "ai_summary" => product.ai_summary
    }
  end

  defp maybe_filter_scene_requests(scene_requests, opts) do
    case Keyword.get(opts, :scene_key) do
      scene_key when is_binary(scene_key) ->
        Enum.filter(scene_requests, &(&1["scene_key"] == scene_key))

      _other ->
        scene_requests
    end
  end

  defp create_run(%Product{} = product, scene_requests, source_images) do
    AI.create_product_lifestyle_generation_run(product, %{
      "status" => "queued",
      "step" => "queued",
      "scene_family" => List.first(scene_requests)["scene_family"],
      "prompt_version" => LifestylePromptBuilder.prompt_version(),
      "requested_count" => length(scene_requests),
      "completed_count" => 0,
      "payload" => %{
        "summary" => "Queued lifestyle preview generation.",
        "scene_keys" => Enum.map(scene_requests, & &1["scene_key"]),
        "source_image_ids" => Enum.map(source_images, & &1.id)
      }
    })
  end

  defp mark_running(run, scene_requests, source_images) do
    AI.update_product_lifestyle_generation_run(run, %{
      "status" => "running",
      "step" => "lifestyle_generating",
      "started_at" => DateTime.utc_now() |> DateTime.truncate(:second),
      "payload" => %{
        "summary" => "Generating lifestyle previews.",
        "scene_keys" => Enum.map(scene_requests, & &1["scene_key"]),
        "source_image_ids" => Enum.map(source_images, & &1.id)
      }
    })
  end

  defp generate_scene_requests(run, product, scene_requests, inputs, source_images, opts) do
    Enum.map_reduce(scene_requests, nil, fn scene_request, model ->
      result = generate_scene(run, product, scene_request, inputs, source_images, opts)
      {result, model || result["model"]}
    end)
  end

  defp generate_scene(run, product, scene_request, inputs, source_images, opts) do
    case AI.generate_lifestyle_image(scene_request, inputs, opts) do
      {:ok, result} ->
        with {:ok, generated_image} <- first_generated_image(result),
             {:ok, body} <- GeneratedImage.decode(generated_image),
             storage_key <- storage_key(product, run, scene_request, generated_image),
             {:ok, _upload} <-
               Storage.upload_object(
                 storage_key,
                 body,
                 provider: Keyword.get(opts, :storage, Storage.provider()),
                 content_type: generated_image.mime_type
               ),
             {:ok, image_record} <-
               Media.create_lifestyle_generated_image(product, %{
                 "storage_key" => storage_key,
                 "content_type" => generated_image.mime_type,
                 "byte_size" => byte_size(body),
                 "lifestyle_generation_run_id" => run.id,
                 "scene_key" => scene_request["scene_key"],
                 "variant_index" => scene_request["variant_index"],
                 "source_image_ids" => Enum.map(source_images, & &1.id),
                 "original_filename" => Path.basename(storage_key)
               }) do
          %{
            "status" => "generated",
            "scene_key" => scene_request["scene_key"],
            "variant_index" => scene_request["variant_index"],
            "model" => result.model,
            "returned_image_count" => length(result.generated_images || []),
            "image" => %{
              "id" => image_record.id,
              "storage_key" => image_record.storage_key,
              "content_type" => image_record.content_type
            }
          }
        else
          {:error, reason} ->
            failed_scene_payload(scene_request, reason, result[:model] || result["model"])

          :error ->
            failed_scene_payload(
              scene_request,
              :invalid_image_data,
              result[:model] || result["model"]
            )
        end

      {:error, reason} ->
        failed_scene_payload(scene_request, reason, nil)
    end
  end

  defp first_generated_image(%{generated_images: [image | _]}) do
    case image do
      %GeneratedImage{} = generated_image ->
        {:ok, generated_image}

      %{mime_type: mime_type, data_base64: data_base64}
      when is_binary(mime_type) and is_binary(data_base64) ->
        {:ok, %GeneratedImage{mime_type: mime_type, data_base64: data_base64}}

      %{"mime_type" => mime_type, "data_base64" => data_base64}
      when is_binary(mime_type) and is_binary(data_base64) ->
        {:ok, %GeneratedImage{mime_type: mime_type, data_base64: data_base64}}

      _ ->
        :error
    end
  end

  defp first_generated_image(_result), do: :error

  defp storage_key(%Product{} = product, run, scene_request, generated_image) do
    extension = GeneratedImage.file_extension(generated_image)

    "users/#{product.user_id}/products/#{product.id}/generated/#{run.id}-#{scene_request["scene_key"]}-#{scene_request["variant_index"]}#{extension}"
  end

  defp finish_run(run, scene_results, model, source_images) do
    generated_results = Enum.filter(scene_results, &(&1["status"] == "generated"))
    failed_results = Enum.filter(scene_results, &(&1["status"] == "failed"))

    {status, step, error_code} =
      cond do
        failed_results == [] -> {"completed", "lifestyle_generated", nil}
        generated_results != [] -> {"partial", "lifestyle_partial", "lifestyle_partial_failure"}
        true -> {"failed", "lifestyle_failed", "lifestyle_generation_failed"}
      end

    error_message =
      failed_results
      |> List.first()
      |> case do
        nil -> nil
        failed_result -> failed_result["error"]
      end

    AI.update_product_lifestyle_generation_run(run, %{
      "status" => status,
      "step" => step,
      "model" => model,
      "completed_count" => length(generated_results),
      "error_code" => error_code,
      "error_message" => error_message,
      "finished_at" => DateTime.utc_now() |> DateTime.truncate(:second),
      "payload" => %{
        "summary" => summary_for(status, generated_results, scene_results),
        "scene_results" => scene_results,
        "source_image_ids" => Enum.map(source_images, & &1.id)
      }
    })
  end

  defp generation_payload(run, scene_results, source_images) do
    %{
      "status" => payload_status(run.status),
      "run_id" => run.id,
      "scene_family" => run.scene_family,
      "prompt_version" => run.prompt_version,
      "model" => run.model,
      "requested_count" => run.requested_count,
      "completed_count" => run.completed_count,
      "source_image_ids" => Enum.map(source_images, & &1.id),
      "scene_results" => scene_results,
      "images" =>
        scene_results
        |> Enum.flat_map(fn
          %{"image" => image} -> [image]
          _ -> []
        end),
      "error" => run.error_message
    }
  end

  defp skipped_payload(reason) do
    %{
      "status" => "skipped",
      "reason" => reason,
      "requested_count" => 0,
      "completed_count" => 0,
      "scene_results" => [],
      "images" => []
    }
  end

  defp failed_payload(reason) do
    %{
      "status" => "failed",
      "requested_count" => 0,
      "completed_count" => 0,
      "scene_results" => [],
      "images" => [],
      "error" => "Lifestyle preview generation failed.",
      "error_reason" => inspect(reason)
    }
  end

  defp failed_scene_payload(scene_request, reason, model) do
    %{
      "status" => "failed",
      "scene_key" => scene_request["scene_key"],
      "variant_index" => scene_request["variant_index"],
      "model" => model,
      "error" => humanize_scene_error(reason),
      "error_reason" => inspect(reason)
    }
  end

  defp summary_for("completed", generated_results, _scene_results) do
    "#{length(generated_results)} lifestyle previews generated."
  end

  defp summary_for("partial", generated_results, scene_results) do
    "#{length(generated_results)}/#{length(scene_results)} lifestyle previews generated."
  end

  defp summary_for(_status, _generated_results, scene_results) do
    "Lifestyle preview generation failed for #{length(scene_results)} scenes."
  end

  defp payload_status("completed"), do: "generated"
  defp payload_status("partial"), do: "partial"
  defp payload_status("failed"), do: "failed"
  defp payload_status(status), do: status

  defp humanize_scene_error({:http_error, status, _body}) do
    "Gemini lifestyle image generation failed with HTTP #{status}."
  end

  defp humanize_scene_error({:request_failed, %Req.TransportError{reason: reason}}) do
    "Gemini lifestyle image generation failed because of a #{reason} transport error."
  end

  defp humanize_scene_error({:no_generated_images, _body}) do
    "Gemini returned no image bytes for this scene."
  end

  defp humanize_scene_error({:image_download_failed, _reason}) do
    "The lifestyle generator could not download one of the source images."
  end

  defp humanize_scene_error(:invalid_image_data) do
    "Gemini returned image data that could not be decoded."
  end

  defp humanize_scene_error(reason), do: "Lifestyle preview generation failed: #{inspect(reason)}"
end
