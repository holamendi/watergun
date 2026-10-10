require "test_helper"

class FetchContainerMetricsJobTest < ActiveSupport::TestCase
  include SshTestHelper

  setup do
    @server = servers(:amd)
    @app = apps(:smol_roda)
  end

  test "creates server check with system metrics" do
    docker_stats_output = {
      "BlockIO" => "1.5kB / 2.3MB",
      "CPUPerc" => "5.32",
      "ID" => "abc123",
      "MemPerc" => "10.45",
      "MemUsage" => "100MiB / 1GiB",
      "Name" => "smol-roda.web.1",
      "NetIO" => "500KB / 0B"
    }.to_json

    system_metrics_output = "25.5\n1073741824\n2147483648\n10737418240\n21474836480\n1.25\n"

    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {cmd: Docker::StatsCommand.new.cmd, stdout: docker_stats_output, exit_code: 0},
        {cmd: System::MetricsCommand.new.cmd, stdout: system_metrics_output, exit_code: 0}
      ]
    )

    assert_difference -> { ServerCheck.count }, 1 do
      FetchContainerMetricsJob.perform_now
    end

    check = @server.checks.last
    assert_equal 25.5, check.cpu_usage
    assert_equal 50.0, check.memory_usage
    assert_equal 1073741824, check.memory_used_bytes
    assert_equal 2147483648, check.memory_total_bytes
    assert_equal 50.0, check.disk_usage
    assert_equal 10737418240, check.disk_used_bytes
    assert_equal 21474836480, check.disk_total_bytes
    assert_equal 1.25, check.load_average
  end

  test "persists large byte metrics for app and service containers and their checks" do
    service = services(:postgres)
    stats = ["#{@app.dokku_id}.web.1", "dokku.postgres.#{service.dokku_id}"].map.with_index do |name, index|
      {
        "BlockIO" => "3GiB / 4GiB",
        "CPUPerc" => "5.32",
        "ID" => "large#{index}",
        "MemPerc" => "50.0",
        "MemUsage" => "5GiB / 10GiB",
        "Name" => name,
        "NetIO" => "6GiB / 7GiB"
      }.to_json
    end.join("\n")

    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {cmd: Docker::StatsCommand.new.cmd, stdout: stats, exit_code: 0},
        {cmd: System::MetricsCommand.new.cmd, stdout: "25.5\n1073741824\n2147483648\n10737418240\n21474836480\n1.25\n", exit_code: 0}
      ]
    )

    FetchContainerMetricsJob.perform_now

    expected = {
      "block_io_read_bytes" => 3.gigabytes,
      "block_io_write_bytes" => 4.gigabytes,
      "memory_used_bytes" => 5.gigabytes,
      "memory_limit_bytes" => 10.gigabytes,
      "network_io_in_bytes" => 6.gigabytes,
      "network_io_out_bytes" => 7.gigabytes
    }
    [@app, service].each do |resource|
      container = resource.containers.sole.reload
      assert container.running?
      assert_equal expected, container.attributes.slice(*expected.keys)
      assert_equal expected, container.checks.sole.reload.attributes.slice(*expected.keys)
    end
  end

  test "does not create server check when metrics command fails" do
    docker_stats_output = {
      "BlockIO" => "1.5kB / 2.3MB",
      "CPUPerc" => "5.32",
      "ID" => "abc123",
      "MemPerc" => "10.45",
      "MemUsage" => "100MiB / 1GiB",
      "Name" => "smol-roda.web.1",
      "NetIO" => "500KB / 0B"
    }.to_json

    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {cmd: Docker::StatsCommand.new.cmd, stdout: docker_stats_output, exit_code: 0},
        {cmd: System::MetricsCommand.new.cmd, stdout: "error", exit_code: 1}
      ]
    )

    assert_no_difference -> { ServerCheck.count } do
      FetchContainerMetricsJob.perform_now
    end
  end
end
