class ChangeEnumColumnTypes < ActiveRecord::Migration[7.1]
  def change
    change_column :containers, :status, :integer
    change_column :deployments, :status, :integer
    change_column :deployments, :source, :integer
    change_column :servers, :status, :integer
    change_column :services, :status, :integer
    change_column :services, :service_type, :integer
    change_column :server_actions, :status, :integer
    change_column :service_links, :status, :integer

    Container.update_all("status = temp_status")
    Deployment.update_all("status = temp_status")
    Deployment.update_all("source = temp_source")
    Server.update_all("status = temp_status")
    Service.update_all("status = temp_status")
    Service.update_all("service_type = temp_service_type")
    ServerAction.update_all("status = temp_status")
    ServiceLink.update_all("status = temp_status")
  end
end
