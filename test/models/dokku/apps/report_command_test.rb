require "test_helper"

class Dokku::Apps::ReportCommandTest < ActiveSupport::TestCase
  test "cmd returns the correct command" do
    cmd = Dokku::Apps::ReportCommand.new(app: "smol-roda").cmd

    assert_equal "dokku apps:report smol-roda --format json", cmd
  end

  test "parse_output returns an AppReport instance with the correct data" do
    output = file_fixture("dokku/apps/report_command_output.txt").read
    report = Dokku::Apps::ReportCommand.new(app: "smol-roda").parse_output(0, output)

    assert_instance_of Dokku::Apps::AppReport, report
    assert_equal Time.zone.at(1736235685), report.created_at
    assert_equal "git-sync", report.deploy_source
    assert_equal "https://github.com/holamendi/smol-roda.git#8e743fa0bedda6a8fea91f85d542a7e02810beac", report.deploy_source_metadata
    assert_equal "/home/dokku/smol-roda", report.dir
    assert_equal false, report.locked
  end
end
