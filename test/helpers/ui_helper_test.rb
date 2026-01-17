require "test_helper"

class UiHelperTest < ActionView::TestCase
  test "container generates div with correct classes" do
    result = container { "content" }
    assert_match(/div/, result)
    assert_match(/max-w-5xl px-4 mx-auto sm:px-6 lg:px-8/, result)
    assert_match(/content/, result)
  end

  test "full_width_container generates div with correct classes" do
    result = full_width_container { "content" }
    assert_match(/div/, result)
    assert_match(/w-full px-4 mx-auto sm:px-6 lg:px-8/, result)
    assert_match(/content/, result)
  end

  test "page_header renders with title and actions" do
    result = page_header("My Title", "Some Actions")
    assert_match(/My Title/, result)
    assert_match(/Some Actions/, result)
  end

  test "page_header renders with block" do
    result = page_header("My Title") { "Block Actions" }
    assert_match(/My Title/, result)
    assert_match(/Block Actions/, result)
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

  test "spinner generates span with loading classes" do
    span = spinner(size: "4", color: "white")
    assert_match(/span/, span)
    assert_match(/loading/, span)
    assert_match(/loading-spinner/, span)
    assert_match(/loading-xs/, span)
  end

  test "submit_button generates button with correct attributes" do
    button = submit_button "Save"
    assert_match(/button/, button)
    assert_match(/Save/, button)
    assert_match(/btn btn-primary/, button)
    assert_match(/data-turbo-submits-with/, button)
  end
end
