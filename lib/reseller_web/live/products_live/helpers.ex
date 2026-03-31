defmodule ResellerWeb.ProductsLive.Helpers do
  @moduledoc false

  alias Reseller.Catalog.Product
  alias Reseller.Media

  @product_filters [
    {"All", "all"},
    {"Draft", "draft"},
    {"Uploading", "uploading"},
    {"Processing", "processing"},
    {"Review", "review"},
    {"Ready", "ready"},
    {"Sold", "sold"},
    {"Archived", "archived"}
  ]

  @manual_product_status_options [
    {"Draft", "draft"},
    {"Review", "review"},
    {"Ready", "ready"},
    {"Sold", "sold"},
    {"Archived", "archived"}
  ]

  @pipeline_stage_specs [
    %{id: :uploads, label: "Files uploaded", icon: "hero-cloud-arrow-up"},
    %{id: :ai_extraction, label: "AI extraction", icon: "hero-sparkles"},
    %{id: :description_draft, label: "Description draft", icon: "hero-document-text"},
    %{id: :price_search, label: "Price search", icon: "hero-banknotes"},
    %{id: :marketplace_texts, label: "Marketplace texts", icon: "hero-megaphone"},
    %{id: :image_processing, label: "Images processing", icon: "hero-photo"},
    %{id: :review, label: "Ready for review", icon: "hero-check-badge"}
  ]

  def product_filters, do: @product_filters
  def manual_product_status_options, do: @manual_product_status_options

  def decimal_to_string(nil), do: nil
  def decimal_to_string(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)

  def format_datetime(nil), do: "—"
  def format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")

  def tag_input_value(nil), do: nil
  def tag_input_value(value) when is_binary(value), do: value
  def tag_input_value(values) when is_list(values), do: Enum.join(values, ", ")
  def tag_input_value(_value), do: nil

  def public_image_url(nil), do: nil

  def public_image_url(image) do
    case Media.public_url_for_image(image) do
      {:ok, url} -> url
      {:error, _reason} -> nil
    end
  end

  def thumbnail_image(%Product{} = product) do
    Enum.find(product.images, &(&1.kind == "original")) || List.first(product.images)
  end

  def humanize_kind(kind) when is_binary(kind) do
    kind
    |> String.replace("_", " ")
    |> Phoenix.Naming.humanize()
  end

  def humanize_kind(_kind), do: "Image"

  def review_ready?(%Product{status: status}),
    do: status in ["review", "ready", "sold", "archived"]

  def review_ready?(_product), do: false

  def retry_processing_available?(%Product{} = product) do
    product.images != [] and
      product.status in ["review", "ready"] and
      match?(%{status: "failed"}, List.first(product.processing_runs || []))
  end

  def retry_processing_available?(_product), do: false

  def pipeline_progress(%Product{} = product) do
    data = pipeline_data(product)
    active_stage_id = active_stage_id(data)
    failed_stage_id = failed_stage_id(data)

    steps =
      Enum.map(@pipeline_stage_specs, fn spec ->
        state =
          cond do
            spec.id == :image_processing and data.variant_warning? ->
              :warning

            stage_complete?(spec.id, data) ->
              :completed

            failed_stage_id == spec.id ->
              :failed

            active_stage_id == spec.id ->
              :active

            true ->
              :pending
          end

        Map.merge(spec, %{state: state, detail: pipeline_step_detail(spec.id, product, data)})
      end)

    completed_count = Enum.count(steps, &(&1.state in [:completed, :warning]))
    total_count = length(steps)
    active_step = Enum.find(steps, &(&1.state == :active))
    failed_step = Enum.find(steps, &(&1.state == :failed))
    warning_step = Enum.find(steps, &(&1.state == :warning))

    %{
      steps: steps,
      completed_count: completed_count,
      total_count: total_count,
      percent: progress_percent(completed_count, total_count),
      headline: pipeline_headline(product, active_step, failed_step, warning_step),
      summary:
        pipeline_summary(
          product,
          active_step,
          failed_step,
          warning_step,
          completed_count,
          total_count
        ),
      state: pipeline_state(active_step, failed_step, warning_step, product)
    }
  end

  def processing_run_detail(run) do
    cond do
      present?(run.error_message) ->
        run.error_message

      present?(get_in(run.payload || %{}, ["variant_generation", "error"])) ->
        get_in(run.payload || %{}, ["variant_generation", "error"])

      present?(get_in(run.payload || %{}, ["detail"])) ->
        get_in(run.payload || %{}, ["detail"])

      true ->
        nil
    end
  end

  def suggested_price(%Product{} = product) do
    product.price || (product.price_research && product.price_research.suggested_target_price)
  end

  def suggested_cost(%Product{} = product) do
    product.cost || (product.price_research && product.price_research.suggested_min_price)
  end

  defp pipeline_data(%Product{} = product) do
    latest_run = List.first(product.processing_runs || [])
    images = product.images || []
    original_images = Enum.filter(images, &(&1.kind == "original"))
    variant_images = Enum.reject(images, &(&1.kind == "original"))
    variant_ready? = variant_images != [] or variant_generated?(latest_run)
    variant_warning? = variant_failed?(latest_run)
    description_draft? = not is_nil(product.description_draft)
    price_research? = not is_nil(product.price_research)
    marketplace_listings? = product.marketplace_listings != []

    downstream_generated? =
      description_draft? or price_research? or marketplace_listings? or variant_ready? or
        variant_warning?

    %{
      latest_run: latest_run,
      original_images: original_images,
      variant_images: variant_images,
      upload_complete?: upload_complete?(original_images),
      ai_extraction_complete?:
        ai_extraction_complete?(product, latest_run, downstream_generated?),
      description_draft_complete?:
        description_draft? or price_research? or marketplace_listings? or variant_ready? or
          variant_warning?,
      price_search_complete?:
        price_research? or marketplace_listings? or variant_ready? or variant_warning?,
      marketplace_texts_complete?: marketplace_listings? or variant_ready? or variant_warning?,
      image_processing_complete?: variant_ready? || variant_warning?,
      review_complete?: review_ready?(product),
      processing_inflight?: processing_inflight?(product, latest_run),
      failed?: match?(%{status: "failed"}, latest_run),
      variant_warning?: variant_warning?
    }
  end

  defp stage_complete?(:uploads, data), do: data.upload_complete?
  defp stage_complete?(:ai_extraction, data), do: data.ai_extraction_complete?
  defp stage_complete?(:description_draft, data), do: data.description_draft_complete?
  defp stage_complete?(:price_search, data), do: data.price_search_complete?
  defp stage_complete?(:marketplace_texts, data), do: data.marketplace_texts_complete?
  defp stage_complete?(:image_processing, data), do: data.image_processing_complete?
  defp stage_complete?(:review, data), do: data.review_complete?

  defp stage_done?(stage_id, data) do
    stage_complete?(stage_id, data) or (stage_id == :image_processing and data.variant_warning?)
  end

  defp active_stage_id(%{processing_inflight?: false}), do: nil

  defp active_stage_id(data) do
    @pipeline_stage_specs
    |> Enum.map(& &1.id)
    |> Enum.find(&(not stage_done?(&1, data)))
  end

  defp failed_stage_id(%{failed?: false}), do: nil

  defp failed_stage_id(data) do
    @pipeline_stage_specs
    |> Enum.map(& &1.id)
    |> Enum.find(&(not stage_done?(&1, data)))
  end

  defp pipeline_step_detail(:uploads, _product, data) do
    total = length(data.original_images)

    uploaded_count =
      Enum.count(
        data.original_images,
        &(&1.processing_status in ["uploaded", "processing", "ready"])
      )

    cond do
      total == 0 -> "Waiting for original product images."
      uploaded_count < total -> "#{uploaded_count}/#{total} original files synced."
      true -> "#{total} original #{pluralize(total, "image", "images")} uploaded."
    end
  end

  defp pipeline_step_detail(:ai_extraction, %Product{} = product, data) do
    cond do
      data.ai_extraction_complete? and present?(product.title) ->
        shorten(product.title, 96)

      data.ai_extraction_complete? and present?(product.ai_summary) ->
        shorten(product.ai_summary, 96)

      true ->
        "Recognizing title, brand, category, and condition clues."
    end
  end

  defp pipeline_step_detail(:description_draft, %Product{} = product, _data) do
    cond do
      product.description_draft && present?(product.description_draft.suggested_title) ->
        shorten(product.description_draft.suggested_title, 96)

      product.description_draft ->
        "Draft copy is ready for review."

      true ->
        "Building seller-friendly title and description copy."
    end
  end

  defp pipeline_step_detail(:price_search, %Product{} = product, _data) do
    cond do
      product.price_research && product.price_research.suggested_target_price ->
        "Target #{money(product.price_research.currency, product.price_research.suggested_target_price)}."

      product.price_research ->
        "Pricing guidance and comparable research are ready."

      true ->
        "Searching comps and grounding an asking price."
    end
  end

  defp pipeline_step_detail(:marketplace_texts, %Product{} = product, _data) do
    listing_count = length(product.marketplace_listings || [])

    cond do
      listing_count > 0 ->
        "#{listing_count} marketplace #{pluralize(listing_count, "draft", "drafts")} ready."

      true ->
        "Generating listing text for eBay, Depop, and Poshmark."
    end
  end

  defp pipeline_step_detail(:image_processing, _product, data) do
    variant_count = length(data.variant_images)

    cond do
      data.variant_warning? ->
        data.latest_run
        |> processing_run_detail()
        |> shorten(120)
        |> case do
          nil -> "Variant generation needs attention, but the product is still reviewable."
          detail -> detail
        end

      variant_count > 0 ->
        "#{variant_count} processed #{pluralize(variant_count, "variant", "variants")} ready."

      true ->
        "Creating background-ready image variants."
    end
  end

  defp pipeline_step_detail(:review, %Product{} = product, _data) do
    case product.status do
      "ready" -> "AI outputs are ready to list or sell."
      "review" -> "A quick human check is still recommended."
      "sold" -> "The product has already been marked sold."
      "archived" -> "The product is archived with all generated outputs intact."
      _other -> "Waiting for the pipeline to unlock the final review step."
    end
  end

  defp pipeline_headline(product, active_step, failed_step, warning_step) do
    cond do
      failed_step ->
        "Processing stalled during #{String.downcase(failed_step.label)}"

      active_step ->
        "Working on #{String.downcase(active_step.label)}"

      warning_step ->
        "Ready for review with warnings"

      review_ready?(product) ->
        "Pipeline complete"

      true ->
        "Waiting for uploads"
    end
  end

  defp pipeline_summary(
         product,
         active_step,
         failed_step,
         warning_step,
         completed_count,
         total_count
       ) do
    cond do
      failed_step ->
        "The latest run stopped before #{String.downcase(failed_step.label)} could finish. You can review the existing data or retry AI."

      active_step ->
        "#{completed_count}/#{total_count} stages finished. This page refreshes automatically while #{String.downcase(active_step.label)} runs."

      warning_step ->
        "#{completed_count}/#{total_count} stages finished. Image variants need attention, but pricing and marketplace drafts are already available."

      review_ready?(product) ->
        "#{completed_count}/#{total_count} stages finished. Review the AI outputs, adjust anything you want, then save."

      true ->
        "Upload files to start the full AI, pricing, and marketplace pipeline."
    end
  end

  defp pipeline_state(active_step, failed_step, warning_step, product) do
    cond do
      failed_step -> :failed
      active_step -> :active
      warning_step -> :warning
      review_ready?(product) -> :completed
      true -> :pending
    end
  end

  defp ai_extraction_complete?(product, latest_run, downstream_generated?) do
    downstream_generated? or
      present?(product.ai_summary) or
      not is_nil(product.ai_confidence) or
      recognition_payload_present?(latest_run)
  end

  defp recognition_payload_present?(%{payload: payload}) when is_map(payload) do
    case Map.get(payload, "final") do
      final when is_map(final) -> map_size(final) > 0
      _other -> false
    end
  end

  defp recognition_payload_present?(_run), do: false

  defp upload_complete?([]), do: false

  defp upload_complete?(original_images) do
    Enum.all?(original_images, &(&1.processing_status in ["uploaded", "processing", "ready"]))
  end

  defp processing_inflight?(%Product{status: status}, latest_run) do
    status in ["uploading", "processing"] or
      match?(%{status: status} when status in ["queued", "running"], latest_run)
  end

  defp variant_generated?(%{payload: payload}) when is_map(payload) do
    get_in(payload, ["variant_generation", "status"]) == "generated"
  end

  defp variant_generated?(_run), do: false

  defp variant_failed?(%{payload: payload, step: step}) when is_map(payload) do
    step == "variants_failed" or get_in(payload, ["variant_generation", "status"]) == "failed"
  end

  defp variant_failed?(%{step: step}), do: step == "variants_failed"
  defp variant_failed?(_run), do: false

  defp progress_percent(_completed_count, 0), do: 0

  defp progress_percent(completed_count, total_count),
    do: round(completed_count * 100 / total_count)

  defp money("USD", %Decimal{} = decimal), do: "$" <> Decimal.to_string(decimal, :normal)

  defp money(currency, %Decimal{} = decimal),
    do: "#{currency} #{Decimal.to_string(decimal, :normal)}"

  defp money(_currency, _value), do: "price ready"

  defp shorten(nil, _limit), do: nil

  defp shorten(value, limit) when is_binary(value) do
    value = String.trim(value)

    if String.length(value) > limit do
      String.slice(value, 0, limit - 1) <> "…"
    else
      value
    end
  end

  defp pluralize(1, singular, _plural), do: singular
  defp pluralize(_count, _singular, plural), do: plural

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
