class RenameServerEventLogToActionLog < ActiveRecord::Migration[7.1]
  def change
    rename_table :server_event_logs, :action_logs
    rename_column :action_logs, :server_event_id, :action_id
    rename_index :actions, "index_actions_on_server_event_log_id", "index_actions_on_action_log_id"
  end
end
