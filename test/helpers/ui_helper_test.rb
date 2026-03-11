require "test_helper"

class UiHelperTest < ActionView::TestCase
  test "container generates div with correct classes" do
    result = container { "content" }

    assert_match(/div/, result)
    assert_match(/page-shell/, result)
    assert_match(/content/, result)
  end

  test "full_width_container generates div with correct classes" do
    result = full_width_container { "content" }

    assert_match(/div/, result)
    assert_match(/w-full px-4 mx-auto sm:px-6 lg:px-8/, result)
    assert_match(/content/, result)
  end

  test "page_header renders title and actions" do
    result = page_header(title: "My Title", actions: "Some Actions")

    assert_match(/My Title/, result)
    assert_match(/Some Actions/, result)
    assert_match(/data-ui-component="page-header"/, result)
  end

  test "button renders a button by default" do
    button = button("Save")

    assert_match(/<button/, button)
    assert_match(/type="button"/, button)
    assert_match(/btn/, button)
    assert_match(/btn-primary/, button)
    assert_match(/data-ui-component="button"/, button)
  end

  test "button renders link when href is provided" do
    button = button("Delete", href: "/projects/1", method: :delete, variant: :danger)

    assert_match(/<a/, button)
    assert_match(/href="\/projects\/1"/, button)
    assert_match(/btn-danger/, button)
    assert_match(/data-turbo-method="delete"/, button)
  end

  test "button supports size variants" do
    assert_match(/btn-xs/, button("XS", size: :xs))
    assert_match(/btn-sm/, button("SM", size: :sm))

    md = button("MD", size: :md)
    refute_match(/btn-sm/, md)
    refute_match(/btn-xs/, md)
  end

  test "submit_button delegates to button with submit type and loading content" do
    button = submit_button("Save")

    assert_match(/<button/, button)
    assert_match(/type="submit"/, button)
    assert_match(/btn-primary/, button)
    assert_match(/data-turbo-submits-with=/, button)
    assert_match(/animate-spin/, button)
  end

  test "submit_button supports destructive alias" do
    button = submit_button("Delete", variant: :destructive)

    assert_match(/btn-danger/, button)
  end

  test "icon_button renders aria label and square sizing" do
    button = icon_button(label: "Edit", icon: "\u270e")

    assert_match(/aria-label="Edit"/, button)
    assert_match(/btn-square/, button)
    assert_match(/data-ui-component="icon-button"/, button)
  end

  test "page_header renders subtitle and actions" do
    result = page_header(title: "Domains", subtitle: "2 configured", actions: "Action")

    assert_match(/Domains/, result)
    assert_match(/2 configured/, result)
    assert_match(/Action/, result)
    assert_match(/data-ui-component="page-header"/, result)
  end

  test "empty_state renders content and actions" do
    result = empty_state(title: "No domains", body: "Add one", actions: "Create")

    assert_match(/No domains/, result)
    assert_match(/Add one/, result)
    assert_match(/Create/, result)
    assert_match(/data-ui-component="empty-state"/, result)
  end

  test "danger_zone renders standard shell" do
    result = danger_zone(title: "Danger", description: "This cannot be undone", actions: "Delete")

    assert_match(/Danger/, result)
    assert_match(/cannot be undone/, result)
    assert_match(/Delete/, result)
    assert_match(/data-ui-component="danger-zone"/, result)
  end

  test "back_link renders canonical back link" do
    result = back_link("All Deployments", "/deployments")

    assert_match(/href="\/deployments"/, result)
    assert_match(/All Deployments/, result)
    assert_match(/data-ui-component="back-link"/, result)
  end

  test "modal renders inline dialog with title and content" do
    result = modal(id: "test_modal", title: "Test Title") { "modal content" }

    assert_match(/<dialog/, result)
    assert_match(/id="test_modal"/, result)
    assert_match(/Test Title/, result)
    assert_match(/modal content/, result)
    assert_match(/data-controller="dialog"/, result)
    assert_no_match(/<turbo-frame/, result)
  end

  test "modal with frame renders turbo-frame inside dialog" do
    result = modal(id: "test_modal", title: "Test Title", frame: "my_frame") { "frame content" }

    assert_match(/<dialog/, result)
    assert_match(/<turbo-frame id="my_frame"/, result)
    assert_match(/turbo:frame-load->dialog#open/, result)
    assert_match(/frame content/, result)
  end

  test "modal_frame renders turbo-frame with header and close button" do
    result = modal_frame("my_frame", title: "Frame Title") { "form content" }

    assert_match(/<turbo-frame id="my_frame"/, result)
    assert_match(/Frame Title/, result)
    assert_match(/form content/, result)
    assert_match(/method="dialog"/, result)
  end

  test "modal_trigger renders standardized trigger contract" do
    result = modal_trigger("+ Add Domain", modal_id: "domain_modal")

    assert_match(/<button/, result)
    assert_match(/data-ui-component="modal-trigger"/, result)
    assert_match(/data-dialog-trigger-target-value="domain_modal"/, result)
    assert_match(/click-&gt;dialog-trigger#open|click->dialog-trigger#open/, result)
  end

  test "badge generates span with correct classes and colors" do
    result = badge("Test Badge", color: :blue)

    assert_match(/span/, result)
    assert_match(/Test Badge/, result)
    assert_match(/badge/, result)
    assert_match(/badge-info/, result)
  end

  test "badge uses neutral as default color" do
    result = badge("Test Badge")

    assert_match(/badge/, result)
    assert_match(/badge-neutral/, result)
  end

  test "status_badge maps status to correct color" do
    {
      "running" => "bg-success-soft text-success",
      "active" => "bg-success-soft text-success",
      "success" => "bg-success-soft text-success",
      "completed" => "bg-success-soft text-success",
      "deploying" => "bg-warning-soft text-warning",
      "pending" => "bg-warning-soft text-warning",
      "warning" => "bg-warning-soft text-warning",
      "failed" => "bg-error-soft text-error",
      "error" => "bg-error-soft text-error",
      "unknown" => "bg-elevated text-text-muted"
    }.each do |status, expected_classes|
      result = status_badge(status)
      assert_match(/#{status.titleize}/, result)
      expected_classes.split.each do |klass|
        assert_match(/#{Regexp.escape(klass)}/, result, "Expected #{klass} in status_badge(#{status})")
      end
    end
  end

  test "status_dot maps status to correct color" do
    {
      "running" => "bg-success shadow-success/50",
      "active" => "bg-success shadow-success/50",
      "success" => "bg-success shadow-success/50",
      "completed" => "bg-success shadow-success/50",
      "deploying" => "bg-warning shadow-warning/50 animate-pulse",
      "pending" => "bg-warning shadow-warning/50 animate-pulse",
      "warning" => "bg-warning shadow-warning/50 animate-pulse",
      "failed" => "bg-error shadow-error/50",
      "error" => "bg-error shadow-error/50",
      "unknown" => "bg-elevated"
    }.each do |status, expected_classes|
      result = status_dot(status)
      expected_classes.split.each do |klass|
        assert_match(/#{Regexp.escape(klass)}/, result, "Expected #{klass} in status_dot(#{status})")
      end
    end
  end

  test "status_dot uses correct size classes" do
    result_default = status_dot("running")
    assert_match(/w-2 h-2/, result_default, "Default size should be w-2 h-2")

    result_size_2 = status_dot("running", size: 2)
    assert_match(/w-2 h-2/, result_size_2, "Size 2 should be w-2 h-2")

    result_size_3 = status_dot("running", size: 3)
    assert_match(/w-3 h-3/, result_size_3, "Size 3 should be w-3 h-3")

    result_size_4 = status_dot("running", size: 4)
    assert_match(/w-4 h-4/, result_size_4, "Size 4 should be w-4 h-4")

    result_size_md = status_dot("running", size: :md)
    assert_match(/w-2\.5 h-2\.5/, result_size_md, "Size :md should be w-2.5 h-2.5")
  end

  test "status_dot falls back to default size for unknown size" do
    result = status_dot("running", size: :unknown)

    assert_match(/w-2 h-2/, result, "Unknown size should fall back to w-2 h-2")
  end

  test "status_dot generates span with correct structure" do
    result = status_dot("running")

    assert_match(/span/, result)
    assert_match(/rounded-full/, result)
    assert_match(/shadow/, result)
    assert_match(/inline-block/, result)
  end
end
