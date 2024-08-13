require "test_helper"

class Docker::ContainerStatsTest < ActiveSupport::TestCase
  setup do
    json_data = {
      "BlockIO" => "1.5kB / 2.3MB",
      "CPUPerc" => "5.32",
      "ID" => "abc123",
      "MemPerc" => "10.45",
      "MemUsage" => "100MiB / 1GiB",
      "Name" => "test_container",
      "NetIO" => "500KB / 0B"
    }.to_json

    @stats = Docker::ContainerStats.new(json_data)
  end

  test "block_io" do
    assert_equal "1.5kB / 2.3MB", @stats.block_io
  end

  test "cpu_perc" do
    assert_equal 5.32, @stats.cpu_perc
  end

  test "id" do
    assert_equal "abc123", @stats.id
  end

  test "mem_perc" do
    assert_equal 10.45, @stats.mem_perc
  end

  test "mem_usage" do
    assert_equal "100MiB / 1GiB", @stats.mem_usage
  end

  test "name" do
    assert_equal "test_container", @stats.name
  end

  test "net_io" do
    assert_equal "500KB / 0B", @stats.net_io
  end

  test "block_io_bytes" do
    assert_equal [1500, 2300000], @stats.block_io_bytes
  end

  test "mem_usage_bytes" do
    assert_equal [104857600, 1073741824], @stats.mem_usage_bytes
  end

  test "net_io_bytes" do
    assert_equal [500000, 0], @stats.net_io_bytes
  end
end
