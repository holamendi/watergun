class AddTempStatusToTables < ActiveRecord::Migration[7.1]
  def change
    add_column :containers, :temp_status, :integer
    add_column :deployments, :temp_status, :integer
    add_column :deployments, :temp_source, :integer
    add_column :servers, :temp_status, :integer
    add_column :services, :temp_status, :integer
    add_column :services, :temp_service_type, :integer
    add_column :server_actions, :temp_status, :integer
    add_column :service_links, :temp_status, :integer
  end
end
