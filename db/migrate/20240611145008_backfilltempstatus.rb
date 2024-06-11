class Backfilltempstatus < ActiveRecord::Migration[7.1]
  def up
    Deployment.find_each do |deployment|
      deployment.update_columns(
        temp_status: Deployment.statuses[deployment.status_before_type_cast],
        temp_source: Deployment.sources[deployment.source_before_type_cast]
      )
    end

    Container.find_each do |container|
      container.update_columns(temp_status: Container.statuses[container.status_before_type_cast])
    end

    Server.find_each do |server|
      say "Updating server #{server.id} with status #{server.status_before_type_cast}"
      server.update_columns(temp_status: Server.statuses[server.status_before_type_cast])
    end

    Service.find_each do |service|
      service.update_columns(
        temp_status: Service.statuses[service.status_before_type_cast],
        temp_service_type: Service.service_types[service.service_type_before_type_cast]
      )
    end

    ServiceLink.find_each do |service_link|
      service_link.update_columns(temp_status: ServiceLink.statuses[service_link.status_before_type_cast])
    end

    ServerAction.find_each do |server_action|
      server_action.update_columns(temp_status: ServerAction.statuses[server_action.status_before_type_cast])
    end
  end
end
