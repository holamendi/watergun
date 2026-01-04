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
