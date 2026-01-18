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

  test "submit_button generates button with correct attributes" do
    button = submit_button "Save"
    assert_match(/button/, button)
    assert_match(/Save/, button)
    assert_match(/from-accent/, button)
    assert_match(/data-turbo-submits-with/, button)
    assert_match(/animate-spin/, button) # loading spinner in turbo_submits_with
  end

  test "submit_button supports variant option" do
    button = submit_button "Delete", variant: :destructive
    assert_match(/bg-error/, button)
    assert_match(/text-error/, button)
  end
end
