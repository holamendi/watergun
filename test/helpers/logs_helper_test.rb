require "test_helper"

class LogsHelperTest < ActionView::TestCase
  test "ansi_to_html escapes HTML in log output" do
    html = ansi_to_html(%(GET /<img src=x onerror="alert(1)"> 404))

    assert_includes html, "&lt;img src=x onerror=&quot;alert(1)&quot;&gt;"
    refute_includes html, "<img"
  end

  test "ansi_to_html escapes HTML inside colored segments" do
    html = ansi_to_html("\e[31m<script>alert(1)</script>\e[0m")

    assert_includes html, "&lt;script&gt;alert(1)&lt;/script&gt;"
    refute_includes html, "<script"
  end

  test "ansi_to_html converts ANSI colors to styled spans" do
    html = ansi_to_html("\e[31mfailed\e[0m")

    assert_equal "<span style='color: #f38ba8; '>failed</b></span>", html
    assert_predicate html, :html_safe?
  end

  test "ansi_to_html leaves its argument unchanged" do
    log = +"\e[1mbuilding\e[0m"

    ansi_to_html(log)

    assert_equal "\e[1mbuilding\e[0m", log
  end
end
