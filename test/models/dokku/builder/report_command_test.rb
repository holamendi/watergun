require "test_helper"

class Dokku::Builder::ReportCommandTest < ActiveSupport::TestCase
  test "cmd returns builder report command" do
    command = Dokku::Builder::ReportCommand.new(app: "blog")

    assert_equal "dokku builder:report blog", command.cmd
  end

  test "parse_output returns selected and computed selected builders" do
    output = <<~OUTPUT
      =====> blog builder information
             Builder computed selected:  dockerfile
             Builder selected:           herokuish
    OUTPUT

    command = Dokku::Builder::ReportCommand.new(app: "blog")
    report = command.parse_output(0, output)

    assert_equal "herokuish", report.selected
    assert_equal "dockerfile", report.computed_selected
  end

  test "parse_output keeps blank values nil" do
    output = <<~OUTPUT
      =====> blog builder information
             Builder computed selected:  dockerfile
             Builder selected:
    OUTPUT

    command = Dokku::Builder::ReportCommand.new(app: "blog")
    report = command.parse_output(0, output)

    assert_nil report.selected
    assert_equal "dockerfile", report.computed_selected
  end

  test "parse_output returns nil on failure" do
    command = Dokku::Builder::ReportCommand.new(app: "blog")

    assert_nil command.parse_output(1, "error")
  end
end
