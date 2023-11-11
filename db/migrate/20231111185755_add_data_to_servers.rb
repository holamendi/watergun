class AddDataToServers < ActiveRecord::Migration[7.1]
  def change
    add_column :servers, :data, :json, default: {}
  end
end
