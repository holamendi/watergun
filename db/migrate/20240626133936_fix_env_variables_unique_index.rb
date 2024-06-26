class FixEnvVariablesUniqueIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index :env_variables, name: "index_env_variables_on_app_id_and_key"
    add_index :env_variables, [:app_id, :key], unique: true, where: "discarded_at IS NULL"
  end
end
