class RenameActionRerefenceOnServerActionLogs < ActiveRecord::Migration[7.1]
  def change
    rename_column :server_action_logs, :action_id, :server_action_id
  end
end
