require "test_helper"

class TabsHelperTest < ActionView::TestCase
  test "tab_link generates link with active classes when condition is true" do
    result = tab_link("Dashboard", "/dashboard", true)

    assert_match(/href="\/dashboard"/, result)
    assert_match(/Dashboard/, result)
    assert_match(/tab/, result)
    assert_match(/tab-active/, result)
    assert_match(/role="tab"/, result)
  end

  test "tab_link generates link with inactive classes when condition is false" do
    result = tab_link("Settings", "/settings", false)

    assert_match(/href="\/settings"/, result)
    assert_match(/Settings/, result)
    assert_match(/tab/, result)
    refute_match(/tab-active/, result)
    assert_match(/role="tab"/, result)
  end

  test "tab_link accepts additional options" do
    result = tab_link("Profile", "/profile", true, data: {turbo_prefetch: false})

    assert_match(/data-turbo-prefetch="false"/, result)
    assert_match(/href="\/profile"/, result)
    assert_match(/Profile/, result)
  end
end
