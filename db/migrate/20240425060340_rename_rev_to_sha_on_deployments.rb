class RenameRevToShaOnDeployments < ActiveRecord::Migration[7.1]
  def change
    rename_column :deployments, :rev, :sha
  end
end
