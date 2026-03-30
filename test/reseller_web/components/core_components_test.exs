defmodule ResellerWeb.CoreComponentsTest do
  use ResellerWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  alias Phoenix.LiveView.JS
  alias ResellerWeb.CoreComponents

  test "flash/1 renders info flash content" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <CoreComponents.flash kind={:info} flash={%{}}>Saved</CoreComponents.flash>
      """)

    assert html =~ "Saved"
    assert html =~ "hero-information-circle"
  end

  test "button/1 renders links and buttons" do
    assigns = %{}

    link_html =
      rendered_to_string(~H"""
      <CoreComponents.button navigate="/app">Go</CoreComponents.button>
      """)

    button_html =
      rendered_to_string(~H"""
      <CoreComponents.button type="button">Save</CoreComponents.button>
      """)

    assert link_html =~ "Go"
    assert link_html =~ "href=\"/app\""
    assert button_html =~ "<button"
    assert button_html =~ "Save"
  end

  test "input/1 renders checkbox, select, textarea, and text inputs" do
    checkbox_html =
      render_component(&CoreComponents.input/1,
        type: "checkbox",
        name: "published",
        label: "Published",
        value: "true"
      )

    select_html =
      render_component(&CoreComponents.input/1,
        type: "select",
        id: "marketplace",
        name: "marketplace",
        label: "Marketplace",
        value: "ebay",
        prompt: "Choose one",
        options: [{"eBay", "ebay"}, {"Depop", "depop"}]
      )

    textarea_html =
      render_component(&CoreComponents.input/1,
        type: "textarea",
        id: "notes",
        name: "notes",
        label: "Notes",
        value: "Draft notes"
      )

    text_html =
      render_component(&CoreComponents.input/1,
        type: "text",
        id: "title",
        name: "title",
        label: "Title",
        value: "Vintage jacket",
        errors: ["is invalid"]
      )

    assert checkbox_html =~ "Published"
    assert checkbox_html =~ "type=\"checkbox\""
    assert select_html =~ "<select"
    assert select_html =~ "Choose one"
    assert textarea_html =~ "<textarea"
    assert textarea_html =~ "Draft notes"
    assert text_html =~ "Vintage jacket"
    assert text_html =~ "is invalid"
  end

  test "header/1, table/1, list/1, and icon/1 render expected content" do
    rows = [%{id: 1, title: "Row one"}]
    assigns = %{rows: rows}

    html =
      rendered_to_string(~H"""
      <div>
        <CoreComponents.header>
          Products
          <:subtitle>Inventory overview</:subtitle>
          <:actions>New</:actions>
        </CoreComponents.header>

        <CoreComponents.table id="products" rows={@rows}>
          <:col :let={row} label="Title">{row.title}</:col>
          <:action :let={row}>
            <span>Open {row.id}</span>
          </:action>
        </CoreComponents.table>

        <CoreComponents.list>
          <:item title="Brand">Patagonia</:item>
        </CoreComponents.list>

        <CoreComponents.icon name="hero-x-mark" class="size-5" />
      </div>
      """)

    assert html =~ "Products"
    assert html =~ "Inventory overview"
    assert html =~ "Row one"
    assert html =~ "Open 1"
    assert html =~ "Patagonia"
    assert html =~ "hero-x-mark"
  end

  test "show/2 and hide/2 return JS commands" do
    assert %JS{} = CoreComponents.show(%JS{}, "#flash")
    assert %JS{} = CoreComponents.hide(%JS{}, "#flash")
  end

  test "translate_errors/2 filters field-specific errors" do
    errors = [
      email: {"can't be blank", []},
      password: {"should be at least %{count} character(s)", [count: 12]}
    ]

    assert CoreComponents.translate_errors(errors, :email) == ["can't be blank"]

    assert CoreComponents.translate_errors(errors, :password) == [
             "should be at least 12 character(s)"
           ]
  end
end
