class AddInProgressAtToDeployments < ActiveRecord::Migration[7.1]
  def change
    add_column :deployments, :started_at, :datetime
    rename_column :deployments, :finished_at, :finished_at
  end
end
