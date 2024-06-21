class AddDeployedAtToService < ActiveRecord::Migration[7.1]
  def change
    add_column :services, :deployed_at, :datetime
  end
end
