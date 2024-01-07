class AddStatusToApp < ActiveRecord::Migration[7.1]
  def change
    add_column :apps, :status, :string
    add_index :apps, :status
  end
end
