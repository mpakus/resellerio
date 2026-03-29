defmodule Reseller.AI.ImageSelection do
  @moduledoc """
  Selects the best set of image inputs for AI recognition.
  """

  @kind_priority %{
    "object_crop" => 0,
    "white_background" => 1,
    "normalized" => 2,
    "original" => 3
  }

  @spec select_inputs([map()], keyword()) :: [map()]
  def select_inputs(images, opts \\ []) when is_list(images) do
    max_images = Keyword.get(opts, :max_images, 5)

    candidates =
      images
      |> Enum.filter(&usable?/1)
      |> Enum.sort_by(&sort_key/1)

    selected = Enum.take(candidates, max_images)

    maybe_include_original(selected, candidates, max_images)
  end

  defp usable?(image) do
    has_mime_type?(image) and has_ai_input?(image)
  end

  defp has_mime_type?(%{"mime_type" => mime_type}) when is_binary(mime_type), do: true
  defp has_mime_type?(%{mime_type: mime_type}) when is_binary(mime_type), do: true
  defp has_mime_type?(_image), do: false

  defp has_ai_input?(%{"inline_data" => %{"data" => _data}}), do: true
  defp has_ai_input?(%{"file_data" => %{"file_uri" => _file_uri}}), do: true
  defp has_ai_input?(%{"data" => data}) when is_binary(data), do: true
  defp has_ai_input?(%{"data_base64" => data}) when is_binary(data), do: true
  defp has_ai_input?(%{"file_uri" => file_uri}) when is_binary(file_uri), do: true
  defp has_ai_input?(%{"uri" => file_uri}) when is_binary(file_uri), do: true
  defp has_ai_input?(%{inline_data: %{data: _data}}), do: true
  defp has_ai_input?(%{file_data: %{file_uri: _file_uri}}), do: true
  defp has_ai_input?(%{data: data}) when is_binary(data), do: true
  defp has_ai_input?(%{data_base64: data}) when is_binary(data), do: true
  defp has_ai_input?(%{file_uri: file_uri}) when is_binary(file_uri), do: true
  defp has_ai_input?(%{uri: file_uri}) when is_binary(file_uri), do: true
  defp has_ai_input?(_image), do: false

  defp sort_key(image) do
    {
      kind_priority(image),
      numeric_field(image, "position"),
      numeric_field(image, "inserted_at_rank")
    }
  end

  defp kind_priority(image) do
    image
    |> string_field("kind")
    |> then(&Map.get(@kind_priority, &1, 4))
  end

  defp numeric_field(image, key) do
    case Map.get(image, key) || Map.get(image, atom_key(key)) do
      value when is_integer(value) -> value
      _ -> 999
    end
  end

  defp string_field(image, key) do
    Map.get(image, key) || Map.get(image, atom_key(key))
  end

  defp atom_key("kind"), do: :kind
  defp atom_key("position"), do: :position
  defp atom_key("inserted_at_rank"), do: :inserted_at_rank

  defp maybe_include_original(selected, candidates, max_images) do
    if Enum.any?(selected, &(string_field(&1, "kind") == "original")) do
      selected
    else
      case Enum.find(candidates, &(string_field(&1, "kind") == "original")) do
        nil ->
          selected

        original when length(selected) < max_images ->
          selected ++ [original]

        original ->
          List.replace_at(selected, -1, original)
      end
    end
  end
end
