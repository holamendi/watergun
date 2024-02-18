module Servers
  class SyncContainerDataJob < ApplicationJob
    queue_as :default

    def perform
      Server.all.each { |server| sync_metrics(server) }
    end

    private

    def sync_metrics(server)
      Current.set(server:, org: server.org) do
        # fetch docker stats
        docker_stats = []
        server.ssh_session do |session|
          session.execute("docker stats --no-stream --format=json").text_output.each_line do |line|
            docker_stats << Docker::Stat.new(JSON.parse(line))
          end
        end
        timestamp = Time.current
        # sync apps
        server.apps.kept.each do |app|
          app_stats = docker_stats.select { |stat| stat.name.start_with?("#{app.dokku_id}.") }
          app_stats.each do |stat|
            # find or create container
            container = app.containers.find_or_initialize_by(cid: stat.id)
            container.assign_attributes(
              name: stat.name,
              block_io: stat.block_io,
              cpu_percentage: stat.cpu_percentage,
              memory_percentage: stat.memory_percentage,
              memory_usage: stat.memory_usage,
              network_io: stat.network_io,
              last_synced_at: timestamp
            )
            container.save!
            # create container metric
            container.container_metrics.create!(
              timestamp:,
              block_io: stat.block_io,
              cpu_percentage: stat.cpu_percentage,
              memory_percentage: stat.memory_percentage,
              memory_usage: stat.memory_usage,
              network_io: stat.network_io
            )
          end
        end

        # sync services
        server.services.kept.each do |service|
          service_stats = docker_stats.select { |stat| stat.name.include?("#{service.service_type}.#{service.dokku_id}") }

          service_stats.each do |stat|
            # find or create container
            container = service.containers.find_or_initialize_by(cid: stat.id)
            container.assign_attributes(
              name: stat.name,
              block_io: stat.block_io,
              cpu_percentage: stat.cpu_percentage,
              memory_percentage: stat.memory_percentage,
              memory_usage: stat.memory_usage,
              network_io: stat.network_io,
              last_synced_at: timestamp
            )
            container.save!
            # create container metric
            container.container_metrics.create!(
              timestamp:,
              block_io: stat.block_io,
              cpu_percentage: stat.cpu_percentage,
              memory_percentage: stat.memory_percentage,
              memory_usage: stat.memory_usage,
              network_io: stat.network_io
            )
          end
        end

        # stop exited containers
        server.containers.running.where.not(cid: docker_stats.map(&:id)).update_all(status: "stopped", stopped_at: timestamp)
      end
    end
  end
end
