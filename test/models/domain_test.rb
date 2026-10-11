require "test_helper"

class DomainTest < ActiveSupport::TestCase
  test "accepts DNS labels with a leading wildcard or punycode IDN" do
    hostnames = ["new.example.com", "*.example.com", "xn--mnich-kva.example", "UPPER.example",
      "a.b", "#{"a" * 63}.example.com", "#{"a" * 63}.#{"b" * 63}.#{"c" * 63}.#{"d" * 61}"]

    hostnames.each do |hostname|
      domain = Domain.new(app: apps(:domain_test_app), hostname: hostname)
      assert domain.valid?, "#{hostname.inspect}: #{domain.errors.full_messages.join(", ")}"
    end
  end

  test "rejects Unicode case-fold equivalents of ASCII letters" do
    ["K.example", "ſ.example"].each do |hostname|
      domain = Domain.new(app: apps(:domain_test_app), hostname: hostname)
      assert_not domain.valid?, "Expected #{hostname.inspect} to be rejected"
    end
  end

  test "rejects hostnames outside the ASCII DNS policy" do
    invalid_hostnames = [
      "example.com;touch /tmp/pwned", "$(id).example.com", "`id`.example.com",
      "example.com\nwhoami", "example.com other.com", "-example.com",
      "example-.com", "example..com", "https://example.com", "example.com:443",
      "foo.*.example.com", "*example.com", "*.com", "münich.example",
      "#{"a" * 64}.example.com", "#{"a" * 63}.#{"b" * 63}.#{"c" * 63}.#{"d" * 63}",
      "example.com.", "_service.example.com", "--help"
    ]

    invalid_hostnames.each do |hostname|
      domain = Domain.new(app: apps(:domain_test_app), hostname: hostname)
      assert_not domain.valid?, "Expected #{hostname.inspect} to be rejected"
      assert domain.errors[:hostname].present?, hostname.inspect
    end
  end
end
