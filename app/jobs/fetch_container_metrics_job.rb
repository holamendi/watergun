class FetchContainerMetricsJob < ApplicationJob
  queue_as :default

  def perform
    Server.all.each { |server| sync_containers(server) }
  end

  private

  def sync_containers(server)
    Current.set(account: server.account, server:) do
      stats = []

      server.ssh_session do |session|
        session.execute("docker stats --no-stream --format=json").text_output.each_line do |line|
          json = JSON.parse(line)

          stats << {
            block_io: json["BlockIO"],
            cpu_percentage: json["CPUPerc"].to_f.round(2),
            id: json["ID"],
            memory_percentage: json["MemPerc"].to_f.round(2),
            memory_usage: json["MemUsage"],
            name: json["Name"],
            network_io: json["NetIO"]
          }
        end
      end

      synced_at = Time.current

      # TODO: I forgot why I added this line
      stats.uniq!

      server.apps.kept.each do |app|
        containers = stats.select { |stat| stat[:name].start_with?("#{app.dokku_id}.") }

        containers.each do |stats|
          container = app.containers.find_or_initialize_by(cid: stats[:id])

          Container.transaction do
            container.update!(stats.to_h.except(:id).merge(last_synced_at: synced_at))
            container.checks.create!(stats.to_h.except(:id, :name).merge(timestamp: synced_at))
          end
        end
      end

      server.services.kept.each do |service|
        containers = stats.select { |stat| stat[:name] == "dokku.#{service.service_type}.#{service.dokku_id}" }

        containers.each do |stats|
          container = service.containers.find_or_initialize_by(cid: stats[:id])

          Container.transaction do
            container.update!(stats.to_h.except(:id).merge(last_synced_at: synced_at))
            container.checks.create!(stats.to_h.except(:id, :name).merge(timestamp: synced_at))
          end
        end
      end

      server.containers
        .running
        .where.not(cid: stats.map { |stat| stat[:id] })
        .update_all(status: "stopped", stopped_at: Time.current)
    end
  end
end
