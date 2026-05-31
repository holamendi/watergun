require "test_helper"

class Dokku::Certs::ReportCommandTest < ActiveSupport::TestCase
  test "cmd returns certs report command" do
    command = Dokku::Certs::ReportCommand.new(app: "blog")

    assert_equal "dokku certs:report blog", command.cmd
  end

  test "parse_output returns ssl enabled true" do
    output = <<~OUTPUT
      =====> blog ssl information
             Ssl enabled: true
    OUTPUT

    command = Dokku::Certs::ReportCommand.new(app: "blog")

    assert_predicate command.parse_output(0, output), :ssl_enabled
  end

  test "parse_output returns ssl enabled false" do
    output = <<~OUTPUT
      =====> blog ssl information
             Ssl enabled: false
    OUTPUT

    command = Dokku::Certs::ReportCommand.new(app: "blog")

    refute_predicate command.parse_output(0, output), :ssl_enabled
  end

  test "parse_output returns nil on failure" do
    command = Dokku::Certs::ReportCommand.new(app: "blog")

    assert_nil command.parse_output(1, "error")
  end
end
