class RenameKeyToNameOnEnvVariables < ActiveRecord::Migration[7.2]
  def change
    rename_column :env_variables, :key, :name
  end
end
