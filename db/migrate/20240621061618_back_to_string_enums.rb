class BackToStringEnums < ActiveRecord::Migration[7.1]
  def change
    change_column :apps, :status, :string
    change_column :containers, :status, :string
    change_column :deployments, :status, :string
    change_column :domains, :status, :string
    change_column :server_actions, :status, :string
    change_column :servers, :status, :string
    change_column :services, :service_type, :string
    change_column :services, :status, :string
    change_column :service_links, :status, :string
  end
end
