defmodule Reseller.Support.Fakes.MediaProcessor do
  @behaviour Reseller.Media.Processor

  @impl true
  def process_image(image_url, profile, opts) do
    send(self(), {:media_processor_called, image_url, profile, opts})

    result =
      case Keyword.get(opts, :variant_results) do
        results when is_map(results) -> Map.get(results, profile.kind)
        _ -> Keyword.get(opts, :variant_result)
      end

    result ||
      {:ok,
       %{
         kind: profile.kind,
         background_style: profile.background_style,
         body: <<137, 80, 78, 71>>,
         content_type: "image/png",
         byte_size: 4,
         width: 1200,
         height: 1600
       }}
  end
end
