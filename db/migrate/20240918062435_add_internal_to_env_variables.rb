class AddInternalToEnvVariables < ActiveRecord::Migration[8.0]
  def change
    add_column :env_variables, :internal, :boolean, default: false
  end
end
