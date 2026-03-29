defmodule Reseller.AI.RecognitionPipeline do
  @moduledoc """
  Orchestrates image selection, Gemini recognition, SerpApi fallback, and
  reconciliation into a single reviewable result.
  """

  alias Reseller.AI
  alias Reseller.AI.ImageSelection
  alias Reseller.AI.Normalizer
  alias Reseller.Search

  @spec run([map()], map(), keyword()) :: {:ok, map()} | {:error, term()}
  def run(images, metadata \\ %{}, opts \\ []) when is_list(images) and is_map(metadata) do
    selected_images = ImageSelection.select_inputs(images, opts)

    if selected_images == [] do
      {:error, :no_recognition_images}
    else
      recognize(selected_images, metadata, opts)
    end
  end

  defp recognize(selected_images, metadata, opts) do
    case AI.recognize_images(selected_images, metadata, ai_opts(opts)) do
      {:ok, recognition_result} ->
        maybe_enrich_with_lens(selected_images, recognition_result, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_enrich_with_lens(selected_images, recognition_result, opts) do
    if Normalizer.low_confidence?(recognition_result, opts) do
      with {:ok, image_url} <- search_image_url(selected_images),
           {:ok, search_result} <- Search.lens_matches(image_url, search_opts(opts)),
           {:ok, reconciliation_result} <-
             AI.reconcile_product(recognition_result.output, search_result, ai_opts(opts)) do
        {:ok,
         build_result(
           selected_images,
           recognition_result,
           search_result,
           reconciliation_result,
           :reconciled
         )}
      else
        {:error, :no_searchable_image_url} ->
          {:ok, build_result(selected_images, recognition_result, nil, nil, :recognized)}

        {:error, reason} ->
          {:ok,
           build_result(
             selected_images,
             recognition_result,
             nil,
             nil,
             :recognized,
             %{attempted: true, error: reason}
           )}
      end
    else
      {:ok, build_result(selected_images, recognition_result, nil, nil, :recognized)}
    end
  end

  defp build_result(
         selected_images,
         recognition_result,
         search_result,
         reconciliation_result,
         status,
         fallback \\ %{attempted: false}
       ) do
    %{
      status: status,
      selected_images: selected_images,
      recognition: recognition_result,
      search: search_result,
      reconciliation: reconciliation_result,
      fallback: fallback,
      final:
        Normalizer.finalize_recognition(recognition_result, search_result, reconciliation_result)
    }
  end

  defp search_image_url(selected_images) do
    case Enum.find_value(selected_images, &external_image_url/1) do
      nil -> {:error, :no_searchable_image_url}
      image_url -> {:ok, image_url}
    end
  end

  defp external_image_url(image) do
    Map.get(image, :external_url) ||
      Map.get(image, "external_url") ||
      Map.get(image, :url) ||
      Map.get(image, "url") ||
      Map.get(image, :uri) ||
      Map.get(image, "uri") ||
      Map.get(image, :file_uri) ||
      Map.get(image, "file_uri")
  end

  defp ai_opts(opts) do
    opts
    |> Keyword.take([:request_fun, :model, :config, :recognize_result, :reconcile_result])
    |> Keyword.put_new(:provider, Keyword.get(opts, :ai_provider, AI.provider()))
  end

  defp search_opts(opts) do
    opts
    |> Keyword.take([:request_fun, :config, :query, :hl, :gl, :lens_result])
    |> Keyword.put_new(:provider, Keyword.get(opts, :search_provider, Search.provider()))
  end
end
