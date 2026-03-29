defmodule Reseller.AI.Normalizer do
  @moduledoc """
  Normalizes recognition and reconciliation outputs into a single reviewable result.
  """

  @spec finalize_recognition(map(), map() | nil, map() | nil) :: map()
  def finalize_recognition(recognition_result, search_result \\ nil, reconciliation_result \\ nil)

  def finalize_recognition(%{output: recognition_output}, search_result, reconciliation_result) do
    search_matches = search_matches(search_result)
    reconciliation_output = output_or_nil(reconciliation_result)

    recognition_output
    |> maybe_put(
      "possible_model",
      reconciliation_output && reconciliation_output["most_likely_model"]
    )
    |> maybe_put(
      "short_card_description",
      reconciliation_output && reconciliation_output["short_card_description"]
    )
    |> maybe_put(
      "review_notes",
      reconciliation_output && reconciliation_output["review_notes"]
    )
    |> maybe_put(
      "same_model_family",
      reconciliation_output && reconciliation_output["same_model_family"]
    )
    |> Map.put("external_match_count", length(search_matches))
    |> Map.put(
      "needs_review",
      needs_review?(recognition_output, reconciliation_output, search_matches)
    )
  end

  def finalize_recognition(recognition_output, search_result, reconciliation_result)
      when is_map(recognition_output) do
    finalize_recognition(%{output: recognition_output}, search_result, reconciliation_result)
  end

  @spec low_confidence?(map(), keyword()) :: boolean()
  def low_confidence?(recognition_result, opts \\ [])

  def low_confidence?(%{output: output}, opts), do: low_confidence?(output, opts)

  def low_confidence?(output, opts) when is_map(output) do
    threshold = Keyword.get(opts, :recognition_confidence_threshold, 0.75)

    confidence =
      case output["confidence_score"] do
        value when is_number(value) -> value
        _ -> 0.0
      end

    confidence < threshold or Map.get(output, "needs_review", false)
  end

  defp search_matches(nil), do: []
  defp search_matches(%{matches: matches}) when is_list(matches), do: matches
  defp search_matches(%{"matches" => matches}) when is_list(matches), do: matches
  defp search_matches(_search_result), do: []

  defp output_or_nil(nil), do: nil
  defp output_or_nil(%{output: output}) when is_map(output), do: output
  defp output_or_nil(%{"output" => output}) when is_map(output), do: output
  defp output_or_nil(output) when is_map(output), do: output
  defp output_or_nil(_output), do: nil

  defp needs_review?(recognition_output, reconciliation_output, search_matches) do
    recognition_output["needs_review"] ||
      reconciliation_flags_review?(reconciliation_output) ||
      (length(search_matches) == 0 and low_confidence?(recognition_output))
  end

  defp reconciliation_flags_review?(nil), do: false

  defp reconciliation_flags_review?(output) do
    output["same_model_family"] == false or
      match?([_ | _], output["review_notes"])
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
