class RenameEnvironmentConfigurationToEnvConfiguration < ActiveRecord::Migration[7.1]
  def change
    rename_table :environment_configurations, :env_configurations
  end
end
