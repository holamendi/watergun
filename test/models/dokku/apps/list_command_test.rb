require "test_helper"

class Dokku::Apps::ListCommandTest < ActiveSupport::TestCase
  test "cmd returns apps list command" do
    assert_equal "dokku apps:list", Dokku::Apps::ListCommand.new.cmd
  end

  test "parse_output parses headered output" do
    output = <<~OUTPUT
      =====> My Apps
      blog
      api
    OUTPUT

    assert_equal ["blog", "api"], Dokku::Apps::ListCommand.new.parse_output(0, output)
  end

  test "parse_output parses quiet output" do
    output = <<~OUTPUT
      blog
      api
    OUTPUT

    assert_equal ["blog", "api"], Dokku::Apps::ListCommand.new.parse_output(0, output)
  end

  test "parse_output returns an empty list on empty output" do
    assert_equal [], Dokku::Apps::ListCommand.new.parse_output(0, "")
  end

  test "parse_output returns an empty list on failure" do
    assert_equal [], Dokku::Apps::ListCommand.new.parse_output(1, "error")
  end
end
