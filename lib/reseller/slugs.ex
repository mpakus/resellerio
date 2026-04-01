defmodule Reseller.Slugs do
  @moduledoc """
  Shared slug normalization helpers.
  """

  @spec slugify(term(), keyword()) :: String.t()
  def slugify(value, opts \\ [])

  def slugify(value, opts) when is_binary(value) do
    max_length = Keyword.get(opts, :max_length)

    value
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace(~r/[^\p{L}\p{N}\s-]/u, "")
    |> String.replace(~r/[\s_-]+/u, "-")
    |> String.trim("-")
    |> maybe_truncate(max_length)
  end

  def slugify(_value, _opts), do: ""

  defp maybe_truncate(value, nil), do: value

  defp maybe_truncate(value, max_length) when is_integer(max_length),
    do: String.slice(value, 0, max_length)
end
