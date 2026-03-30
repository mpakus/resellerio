defmodule ResellerWeb.UIComponentsTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias ResellerWeb.UIComponents

  test "section_intro/1 renders eyebrow, title, description, and actions" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <UIComponents.section_intro
        eyebrow="Inventory"
        title="Create, upload, and manage inventory."
        description="One shared intro pattern for page-level content."
      >
        <:actions>
          <button type="button">New product</button>
        </:actions>
      </UIComponents.section_intro>
      """)

    assert html =~ "Inventory"
    assert html =~ "Create, upload, and manage inventory."
    assert html =~ "One shared intro pattern for page-level content."
    assert html =~ "New product"
  end

  test "surface/1, metric_card/1, and feature_tile/1 render shared panels" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <div>
        <UIComponents.surface id="panel" variant="soft" padding="md">
          Shared panel
        </UIComponents.surface>

        <UIComponents.metric_card
          id="metric"
          label="Products"
          value="12"
          description="Total active products."
        />

        <UIComponents.feature_tile
          id="tile"
          patch="/app/products"
          eyebrow="Capture"
          title="Create product"
          description="Use one consistent tile for quick actions."
        />
      </div>
      """)

    assert html =~ "Shared panel"
    assert html =~ "Products"
    assert html =~ "Total active products."
    assert html =~ "Create product"
    assert html =~ "href=\"/app/products\""
  end

  test "status_badge/1 renders consistent lifecycle styling" do
    html = render_component(&UIComponents.status_badge/1, status: "ready")

    assert html =~ "ready"
    assert html =~ "rounded-full"
    assert html =~ "text-success"
  end

  test "status_badge_classes/1 covers default and known statuses" do
    assert UIComponents.status_badge_classes("processing") |> Enum.join(" ") =~ "text-info"
    assert UIComponents.status_badge_classes("ready") |> Enum.join(" ") =~ "text-success"
    assert UIComponents.status_badge_classes("unknown") |> Enum.join(" ") =~ "bg-base-200"
  end
end
