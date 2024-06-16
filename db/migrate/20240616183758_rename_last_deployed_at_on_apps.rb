class RenameLastDeployedAtOnApps < ActiveRecord::Migration[7.1]
  def change
    rename_column :apps, :last_deployed_at, :deployed_at
  end
end
