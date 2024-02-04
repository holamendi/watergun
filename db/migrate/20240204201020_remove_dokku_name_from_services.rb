class RemoveDokkuNameFromServices < ActiveRecord::Migration[7.1]
  def change
    remove_column :services, :dokku_name, :string
  end
end
