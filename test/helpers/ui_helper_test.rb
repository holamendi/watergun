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
    assert_match(/bg-blue-400\/10/, result)
    assert_match(/text-blue-400/, result)
    assert_match(/ring-blue-400\/30/, result)
  end

  test "badge uses gray as default color" do
    result = badge("Test Badge")
    assert_match(/bg-gray-400\/10/, result)
    assert_match(/text-gray-400/, result)
    assert_match(/ring-gray-400\/20/, result)
  end

  test "status_badge maps status to correct color" do
    {
      "deploying" => :blue,
      "error" => :red,
      "pending" => :yellow,
      "success" => :green
    }.each do |status, color|
      result = status_badge(status)
      assert_match(/#{status.humanize}/, result)
      color_class = case color
      when :blue then "bg-blue-400"
      when :red then "bg-red-400"
      when :yellow then "bg-yellow-400"
      when :green then "bg-green-500"
      end
      assert_match(/#{color_class}/, result)
    end
  end

  test "spinner generates svg with correct attributes" do
    svg = spinner(size: "4", color: "red-500")
    assert_match(/svg/, svg)
    assert_match(/size-4/, svg)
    assert_match(/text-red-500/, svg)
  end

  test "submit_button generates button with correct attributes" do
    button = submit_button "Save"
    assert_match(/button/, button)
    assert_match(/Save/, button)
    assert_match(/data-turbo-submits-with/, button)
  end
end
