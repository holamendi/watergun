class DropEnvConfigurations < ActiveRecord::Migration[7.1]
  def change
    drop_table :env_configurations
  end
end
