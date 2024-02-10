class RenameEventableToActionable < ActiveRecord::Migration[7.1]
  def change
    rename_column :actions, :eventable_type, :actionable_type
    rename_column :actions, :eventable_id, :actionable_id
    rename_index :actions, "index_server_events_on_eventable", "index_server_events_on_actionable"
  end
end
