require "test_helper"

class System::ServerStatsTest < ActiveSupport::TestCase
  setup do
    @json = file_fixture("system/metrics_command_output.txt").read
    @stats = System::ServerStats.new(@json)
  end

  test "cpu_usage" do
    assert_equal 25.5, @stats.cpu_usage
  end

  test "memory_usage is calculated from bytes" do
    assert_equal 50.0, @stats.memory_usage
  end

  test "memory_used_bytes" do
    assert_equal 1073741824, @stats.memory_used_bytes
  end

  test "memory_total_bytes" do
    assert_equal 2147483648, @stats.memory_total_bytes
  end

  test "disk_usage is calculated from bytes" do
    assert_equal 50.0, @stats.disk_usage
  end

  test "disk_used_bytes" do
    assert_equal 10737418240, @stats.disk_used_bytes
  end

  test "disk_total_bytes" do
    assert_equal 21474836480, @stats.disk_total_bytes
  end

  test "load_average" do
    assert_equal 1.25, @stats.load_average
  end
end
