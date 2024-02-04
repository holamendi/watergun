class RenameAppsDokkuNameToDokkuId < ActiveRecord::Migration[7.1]
  def change
    rename_column :apps, :dokku_name, :dokku_id
  end
end
