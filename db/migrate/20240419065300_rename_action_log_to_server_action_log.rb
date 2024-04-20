class RenameActionLogToServerActionLog < ActiveRecord::Migration[7.1]
  def change
    rename_table :action_logs, :server_action_logs
  end
end
