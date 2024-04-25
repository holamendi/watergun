class RenamePolymorphicEnvironmentConfigurableToEnvConfigurableOnEnvConfiguration < ActiveRecord::Migration[7.1]
  def change
    rename_column :env_configurations, :environment_configurable_id, :env_configurable_id
    rename_column :env_configurations, :environment_configurable_type, :env_configurable_type
  end
end
