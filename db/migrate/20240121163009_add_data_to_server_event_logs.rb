class AddDataToServerEventLogs < ActiveRecord::Migration[7.1]
  def change
    remove_column :server_event_logs, :content, :text
    add_column :server_event_logs, :data, :json, null: false, default: {}
  end
end
