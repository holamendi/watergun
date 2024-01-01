class AddDataToServerEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :server_events, :data, :json, null: false, default: {}
  end
end
