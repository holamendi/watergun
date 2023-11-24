class AddDataToApps < ActiveRecord::Migration[7.1]
  def change
    add_column :apps, :data, :json, null: false, default: {}
  end
end
