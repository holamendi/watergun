class RemoveActionTypeFromActions < ActiveRecord::Migration[7.1]
  def change
    remove_column :actions, :action_type, :string
  end
end
