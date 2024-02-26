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
      Server.all.each { |server| sync_containers(server) }
    end

    private

    def sync_containers(server)
      Current.set(org: server.org, server:) do
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

        synced_at = Time.current
        docker_container_stats.uniq!

        (server.apps.kept + server.services.kept).each do |entity|
          containers = docker_container_stats.select { |stat| stat.name.include?(entity.dokku_id) }

          containers.each do |stats|
            container = entity.containers.find_or_initialize_by(cid: stats.id)

            ApplicationRecord.transaction do
              container.update!(stats.to_h.except(:id).merge(last_synced_at: synced_at))
              container.container_metrics.create!(stats.to_h.except(:id, :name).merge(timestamp: synced_at))
            end
          end
        end

        server.containers
          .running
          .where.not(cid: docker_container_stats.map(&:id))
          .update_all(status: "stopped", stopped_at: Time.current)
      end
    end
  end
end
