require "test_helper"

class Dokku::Services::ListCommandTest < ActiveSupport::TestCase
  test "cmd returns service list command" do
    command = Dokku::Services::ListCommand.new(plugin: "postgres")

    assert_equal "dokku postgres:list", command.cmd
  end

  test "parse_output parses headered output" do
    output = <<~OUTPUT
      =====> Postgres Services
      primary-db
      analytics-db
    OUTPUT

    command = Dokku::Services::ListCommand.new(plugin: "postgres")

    assert_equal ["primary-db", "analytics-db"], command.parse_output(0, output)
  end

  test "parse_output parses quiet output" do
    output = <<~OUTPUT
      primary-db
      analytics-db
    OUTPUT

    command = Dokku::Services::ListCommand.new(plugin: "postgres")

    assert_equal ["primary-db", "analytics-db"], command.parse_output(0, output)
  end

  test "parse_output returns an empty list on empty output" do
    command = Dokku::Services::ListCommand.new(plugin: "postgres")

    assert_equal [], command.parse_output(0, "")
  end

  test "parse_output returns an empty list on failure" do
    command = Dokku::Services::ListCommand.new(plugin: "postgres")

    assert_equal [], command.parse_output(1, "error")
  end
end
