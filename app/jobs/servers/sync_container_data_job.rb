module Servers
  class SyncContainerDataJob < ApplicationJob
    queue_as :default

    ContainerStat = Data.define(
      :block_io,
      :cpu_percentage,
      :id,
      :memory_percentage,
      :memory_usage,
      :name,
      :network_io
    )

    def perform
      Server.all.each { |server| sync_metrics(server) }
    end

    private

    def sync_metrics(server)
      Current.set(server:, org: server.org) do
        docker_container_stats = []

        server.ssh_session do |session|
          session.execute("docker stats --no-stream --format=json").text_output.each_line do |line|
            stats = JSON.parse(line)

            docker_container_stats << ContainerStat.new(
              block_io: stats["BlockIO"],
              cpu_percentage: stats["CPUPerc"].to_f.round(2),
              id: stats["ID"],
              memory_percentage: stats["MemPerc"].to_f.round(2),
              memory_usage: stats["MemUsage"],
              name: stats["Name"],
              network_io: stats["NetIO"]
            )
          end
        end

        timestamp = Time.current
        docker_container_stats.uniq!

        server.apps.kept.each do |app|
          app_stats = docker_container_stats.select { |stat| stat.name.start_with?("#{app.dokku_id}.") }
          app_stats.each do |stats|
            container = app.containers.find_or_initialize_by(cid: stats.id)
            container.update!(stats.to_h.except(:id).merge(last_synced_at: timestamp))
            container.container_metrics.create!(stats.to_h.except(:id, :name).merge(timestamp:))
          end
        end

        server.services.kept.each do |service|
          service_stats = docker_container_stats.select { |stat| stat.name.include?("#{service.service_type}.#{service.dokku_id}") }
          service_stats.each do |stats|
            container = service.containers.find_or_initialize_by(cid: stats.id)
            container.update!(stats.to_h.except(:id).merge(last_synced_at: timestamp))
            container.container_metrics.create!(stats.to_h.except(:id, :name).merge(timestamp:))
          end
        end

        server.containers.running.where.not(cid: docker_container_stats.map(&:id)).update_all(status: "stopped", stopped_at: timestamp)
      end
    end
  end
end
