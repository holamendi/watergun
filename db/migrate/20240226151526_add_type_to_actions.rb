class AddTypeToActions < ActiveRecord::Migration[7.1]
  def change
    add_column :actions, :type, :string
  end
end
