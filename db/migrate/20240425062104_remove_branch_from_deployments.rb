class RemoveBranchFromDeployments < ActiveRecord::Migration[7.1]
  def change
    remove_column :deployments, :branch, :string
  end
end
