class AddSshCommandsToServerEventLog < ActiveRecord::Migration[7.1]
  def change
    remove_column :server_event_logs, :data, :json
    add_column :server_event_logs, :ssh_commands, :json, null: false, default: []
  end
end
