defmodule ResellerWeb.UIComponents do
  @moduledoc """
  Shared UI primitives for the ResellerIO web interface.
  """
  use Phoenix.Component

  attr :id, :string, default: nil
  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :class, :any, default: []
  attr :title_class, :string, default: nil

  slot :actions
  slot :inner_block

  def section_intro(assigns) do
    ~H"""
    <div id={@id} class={["flex flex-col gap-5 lg:flex-row lg:items-end lg:justify-between", @class]}>
      <div class="max-w-3xl">
        <p :if={@eyebrow} class="text-xs font-semibold uppercase tracking-[0.35em] text-primary">
          {@eyebrow}
        </p>
        <h1 class={[
          @title_class ||
            "reseller-display mt-4 text-5xl font-semibold tracking-[-0.04em] text-balance"
        ]}>
          {@title}
        </h1>
        <p :if={@description} class="mt-5 max-w-2xl text-base leading-7 text-base-content/70">
          {@description}
        </p>
        {render_slot(@inner_block)}
      </div>

      <div :if={@actions != []} class="flex shrink-0 flex-wrap items-center gap-3">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  attr :id, :string, default: nil
  attr :tag, :string, default: "div"
  attr :variant, :string, default: "default", values: ~w(default soft ghost contrast interactive)
  attr :padding, :string, default: "lg", values: ~w(none sm md lg xl)
  attr :class, :any, default: []
  attr :rest, :global

  slot :inner_block, required: true

  def surface(assigns) do
    ~H"""
    <.dynamic_tag
      id={@id}
      tag_name={@tag}
      class={[
        "overflow-hidden border",
        surface_variant_classes(@variant),
        surface_padding_classes(@padding),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.dynamic_tag>
    """
  end

  attr :id, :string, default: nil
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :description, :string, default: nil
  attr :class, :any, default: []

  def metric_card(assigns) do
    ~H"""
    <.surface id={@id} tag="article" class={@class}>
      <p class="text-xs uppercase tracking-[0.28em] text-base-content/50">{@label}</p>
      <p class="mt-4 text-3xl font-semibold tracking-[-0.03em]">{@value}</p>
      <p :if={@description} class="mt-3 text-sm leading-6 text-base-content/68">{@description}</p>
    </.surface>
    """
  end

  attr :id, :string, default: nil
  attr :eyebrow, :string, default: nil
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :accent, :string, default: "primary", values: ~w(primary secondary accent neutral)
  attr :class, :any, default: []
  attr :rest, :global, include: ~w(href navigate patch)

  slot :meta
  slot :inner_block

  def feature_tile(%{rest: rest} = assigns) do
    interactive? = !!(rest[:href] || rest[:navigate] || rest[:patch])

    assigns =
      assigns
      |> assign(:interactive?, interactive?)
      |> assign(:tile_class, feature_tile_classes(assigns.accent, interactive?))

    if interactive? do
      ~H"""
      <.link id={@id} class={[@tile_class, @class]} {@rest}>
        <p :if={@eyebrow} class="text-xs uppercase tracking-[0.28em] text-base-content/50">
          {@eyebrow}
        </p>
        <p class="mt-4 text-xl font-semibold tracking-[-0.03em]">{@title}</p>
        <p :if={@description} class="mt-3 text-sm leading-6 text-base-content/68">{@description}</p>
        {render_slot(@inner_block)}
        <div :if={@meta != []} class="mt-4 flex flex-wrap items-center gap-2">{render_slot(@meta)}</div>
      </.link>
      """
    else
      ~H"""
      <.surface id={@id} tag="article" variant="interactive" class={[@tile_class, @class]}>
        <p :if={@eyebrow} class="text-xs uppercase tracking-[0.28em] text-base-content/50">
          {@eyebrow}
        </p>
        <p class="mt-4 text-xl font-semibold tracking-[-0.03em]">{@title}</p>
        <p :if={@description} class="mt-3 text-sm leading-6 text-base-content/68">{@description}</p>
        {render_slot(@inner_block)}
        <div :if={@meta != []} class="mt-4 flex flex-wrap items-center gap-2">{render_slot(@meta)}</div>
      </.surface>
      """
    end
  end

  attr :id, :string, default: nil
  attr :status, :string, required: true
  attr :class, :any, default: []

  def status_badge(assigns) do
    ~H"""
    <span id={@id} class={[status_badge_classes(@status), @class]}>
      {@status}
    </span>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :upload, :any, required: true
  attr :cancel_event, :string, required: true
  attr :errors, :list, default: []

  attr :input_class, :string,
    default: "file-input file-input-bordered file-input-sm w-full max-w-xs"

  def upload_panel(assigns) do
    ~H"""
    <.surface
      id={@id}
      variant="soft"
      padding="md"
      class="border-dashed border-base-300 bg-base-50"
    >
      <div class="flex items-center justify-between gap-4">
        <div>
          <p class="text-sm font-semibold">{@title}</p>
          <p class="mt-1 text-sm text-base-content/60">{@description}</p>
        </div>
        <.live_file_input upload={@upload} class={@input_class} />
      </div>

      <div :if={@upload.entries != []} class="mt-4 space-y-2">
        <.surface
          :for={entry <- @upload.entries}
          tag="div"
          variant="default"
          padding="sm"
          class="flex items-center justify-between gap-4 text-sm"
        >
          <div>
            <p class="font-medium">{entry.client_name}</p>
            <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">
              {entry.progress}% uploaded
            </p>
          </div>
          <button
            type="button"
            phx-click={@cancel_event}
            phx-value-ref={entry.ref}
            class="btn btn-ghost btn-xs rounded-full"
          >
            Remove
          </button>
        </.surface>
      </div>

      <p :for={error <- @errors} class="mt-3 text-sm text-error">{error}</p>
    </.surface>
    """
  end

  def status_badge_classes(status) do
    [
      "inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em]",
      case status do
        "ready" -> "border border-success/20 bg-success/15 text-success"
        "review" -> "border border-warning/25 bg-warning/20 text-warning"
        "processing" -> "border border-info/20 bg-info/15 text-info"
        "uploading" -> "border border-info/20 bg-info/15 text-info"
        "sold" -> "border border-neutral/10 bg-neutral text-neutral-content"
        "archived" -> "border border-base-300 bg-base-300 text-base-content/70"
        "completed" -> "border border-success/20 bg-success/15 text-success"
        "running" -> "border border-info/20 bg-info/15 text-info"
        "stalled" -> "border border-warning/25 bg-warning/20 text-warning"
        "failed" -> "border border-error/20 bg-error/15 text-error"
        _other -> "border border-base-300 bg-base-200 text-base-content/75"
      end
    ]
  end

  defp surface_variant_classes("default") do
    "rounded-[1.75rem] border-base-300 bg-base-100 shadow-[0_24px_70px_rgba(20,20,20,0.08)]"
  end

  defp surface_variant_classes("soft") do
    "rounded-[1.5rem] border-base-300 bg-base-50/90"
  end

  defp surface_variant_classes("ghost") do
    "rounded-[1.5rem] border-base-300 bg-base-200/60"
  end

  defp surface_variant_classes("contrast") do
    "rounded-[2rem] border-base-300/70 bg-neutral text-neutral-content shadow-[0_30px_80px_rgba(20,20,20,0.18)]"
  end

  defp surface_variant_classes("interactive") do
    "rounded-[1.75rem] border-base-300 bg-base-100 transition duration-300 hover:-translate-y-1 hover:shadow-[0_24px_70px_rgba(20,20,20,0.12)]"
  end

  defp surface_padding_classes("none"), do: nil
  defp surface_padding_classes("sm"), do: "px-4 py-4"
  defp surface_padding_classes("md"), do: "p-4"
  defp surface_padding_classes("lg"), do: "p-6"
  defp surface_padding_classes("xl"), do: "px-6 py-8 sm:px-8 lg:px-12 lg:py-12"

  defp feature_tile_classes(accent, interactive?) do
    [
      interactive? && "block",
      "h-full",
      case accent do
        "primary" -> "hover:border-primary/40"
        "secondary" -> "hover:border-secondary/40"
        "accent" -> "hover:border-accent/40"
        _other -> "hover:border-neutral/40"
      end
    ]
  end
end
