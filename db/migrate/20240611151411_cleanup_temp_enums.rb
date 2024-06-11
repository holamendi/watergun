class CleanupTempEnums < ActiveRecord::Migration[7.1]
  def change
    remove_column :containers, :temp_status, :integer
    remove_column :deployments, :temp_status, :integer
    remove_column :deployments, :temp_source, :integer
    remove_column :servers, :temp_status, :integer
    remove_column :services, :temp_status, :integer
    remove_column :services, :temp_service_type, :integer
    remove_column :server_actions, :temp_status, :integer
    remove_column :service_links, :temp_status, :integer

    add_index :deployments, :status, if_not_exists: true
    add_index :deployments, :source, if_not_exists: true
    add_index :servers, :status, if_not_exists: true
    add_index :services, :status, if_not_exists: true
    add_index :services, :service_type, if_not_exists: true
    add_index :server_actions, :status, if_not_exists: true
    add_index :service_links, :status, if_not_exists: true
  end
end
