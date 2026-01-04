require "test_helper"

class System::MetricsCommandTest < ActiveSupport::TestCase
  test "cmd returns a shell command" do
    cmd = System::MetricsCommand.new.cmd

    assert_includes cmd, "/proc/stat"
    assert_includes cmd, "/proc/meminfo"
    assert_includes cmd, "/proc/loadavg"
    assert_includes cmd, "df -B1"
  end

  test "parse_output returns ServerStats on success" do
    output = file_fixture("system/metrics_command_output.txt").read
    stats = System::MetricsCommand.new.parse_output(0, output)

    assert_instance_of System::ServerStats, stats
    assert_equal 25.5, stats.cpu_usage
    assert_equal 50.0, stats.memory_usage
    assert_equal 1.25, stats.load_average
  end

  test "parse_output returns nil on failure" do
    result = System::MetricsCommand.new.parse_output(1, "error")

    assert_nil result
  end
end
