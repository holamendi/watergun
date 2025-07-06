require "test_helper"

class TabsHelperTest < ActionView::TestCase
  test "tab_link generates link with active classes when condition is true" do
    result = tab_link("Dashboard", "/dashboard", true)

    assert_match(/href="\/dashboard"/, result)
    assert_match(/Dashboard/, result)
    assert_match(/border-teal-500/, result)
    assert_match(/text-teal-600/, result)
    refute_match(/border-transparent/, result)
    refute_match(/text-gray-500/, result)
  end

  test "tab_link generates link with inactive classes when condition is false" do
    result = tab_link("Settings", "/settings", false)

    assert_match(/href="\/settings"/, result)
    assert_match(/Settings/, result)
    assert_match(/border-transparent/, result)
    assert_match(/text-gray-500/, result)
    assert_match(/hover:border-gray-300/, result)
    assert_match(/hover:text-gray-700/, result)
    refute_match(/border-teal-500/, result)
    refute_match(/text-teal-600/, result)
  end

  test "tab_link accepts additional options" do
    result = tab_link("Profile", "/profile", true, data: {turbo_prefetch: false})

    assert_match(/data-turbo-prefetch="false"/, result)
    assert_match(/href="\/profile"/, result)
    assert_match(/Profile/, result)
  end
end
