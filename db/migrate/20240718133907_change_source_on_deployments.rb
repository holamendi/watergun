class ChangeSourceOnDeployments < ActiveRecord::Migration[7.2]
  def change
    remove_column :deployments, :source, :integer
    add_column :deployments, :source, :string
  end
end
