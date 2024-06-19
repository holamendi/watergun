class AddDataToDeployments < ActiveRecord::Migration[7.1]
  def change
    add_column :deployments, :data, :json, default: {}
  end
end
