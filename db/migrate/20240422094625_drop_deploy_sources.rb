class DropDeploySources < ActiveRecord::Migration[7.1]
  def change
    drop_table :deploy_sources
  end
end
