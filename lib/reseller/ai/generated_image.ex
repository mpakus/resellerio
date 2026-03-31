defmodule Reseller.AI.GeneratedImage do
  @enforce_keys [:mime_type, :data_base64]
  defstruct [:mime_type, :data_base64]

  @type t :: %__MODULE__{
          mime_type: String.t(),
          data_base64: String.t()
        }

  @spec from_part(map()) :: t() | nil
  def from_part(%{"inline_data" => %{"mime_type" => mime_type, "data" => data}})
      when is_binary(mime_type) and is_binary(data) do
    %__MODULE__{mime_type: mime_type, data_base64: data}
  end

  def from_part(%{"inlineData" => %{"mimeType" => mime_type, "data" => data}})
      when is_binary(mime_type) and is_binary(data) do
    %__MODULE__{mime_type: mime_type, data_base64: data}
  end

  def from_part(%{"inlineData" => %{"mime_type" => mime_type, "data" => data}})
      when is_binary(mime_type) and is_binary(data) do
    %__MODULE__{mime_type: mime_type, data_base64: data}
  end

  def from_part(_part), do: nil

  @spec decode(t()) :: {:ok, binary()} | :error
  def decode(%__MODULE__{data_base64: data_base64}) do
    Base.decode64(data_base64)
  end

  @spec file_extension(t()) :: String.t()
  def file_extension(%__MODULE__{mime_type: "image/png"}), do: ".png"
  def file_extension(%__MODULE__{mime_type: "image/jpeg"}), do: ".jpg"
  def file_extension(%__MODULE__{mime_type: "image/jpg"}), do: ".jpg"
  def file_extension(%__MODULE__{mime_type: "image/webp"}), do: ".webp"
  def file_extension(%__MODULE__{}), do: ".bin"
end
