class FetchContainerMetricsJob < ApplicationJob
  queue_as :default

  retry_on Errno::ECONNRESET, Net::SSH::Disconnect, wait: 1.second, attempts: 3

  def perform
    Server.all.each { |server| sync_containers(server) }
  end

  private

  def sync_containers(server)
    return unless server.apps.kept.any? || server.services.kept.any?

    stats = nil
    server_stats = nil

    server.ssh_session do |ssh|
      stats = ssh.execute!(Docker::StatsCommand.new).parsed_output
      server_stats = ssh.execute(System::MetricsCommand.new).parsed_output
    end

    checked_at = Time.current
    stats.uniq!

    save_server_check!(server, server_stats, checked_at) if server_stats

    server.apps.kept.each do |app|
      app_stats = stats.select { |stat| stat.name.start_with?("#{app.dokku_id}.") }
      save_metrics!(server, app_stats, app, checked_at)
    end

    server.services.kept.each do |service|
      service_stats = stats.select { |stat| stat.name == "dokku.#{service.service_type}.#{service.dokku_id}" }
      save_metrics!(server, service_stats, service, checked_at)
    end

    # stop all containers that are not in stats
    running_container_ids = stats.map(&:id)
    server.containers.running.where.not(cid: running_container_ids).stop_all
  end

  def save_metrics!(server, container_stats, containerizable, checked_at)
    container_stats.each do |stats|
      container = containerizable.containers.find_or_initialize_by(cid: stats.id, server:)

      Container.transaction do
        container.update!(metrics_attributes(stats).merge(name: stats.name, checked_at:))
        container.checks.create!(metrics_attributes(stats).merge(timestamp: checked_at))
      end
    end
  end

  def metrics_attributes(container_stats)
    {
      block_io_read_bytes: container_stats.block_io_bytes.first,
      block_io_write_bytes: container_stats.block_io_bytes.last,
      network_io_in_bytes: container_stats.net_io_bytes.first,
      network_io_out_bytes: container_stats.net_io_bytes.last,
      cpu_percentage: container_stats.cpu_perc,
      memory_percentage: container_stats.mem_perc,
      memory_used_bytes: container_stats.mem_usage_bytes.first,
      memory_limit_bytes: container_stats.mem_usage_bytes.last
    }
  end

  def save_server_check!(server, stats, checked_at)
    server.checks.create!(
      cpu_usage: stats.cpu_usage,
      memory_usage: stats.memory_usage,
      memory_used_bytes: stats.memory_used_bytes,
      memory_total_bytes: stats.memory_total_bytes,
      disk_usage: stats.disk_usage,
      disk_used_bytes: stats.disk_used_bytes,
      disk_total_bytes: stats.disk_total_bytes,
      load_average: stats.load_average,
      timestamp: checked_at
    )
  end
end
