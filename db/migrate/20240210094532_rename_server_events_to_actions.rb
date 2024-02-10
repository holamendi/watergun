class RenameServerEventsToActions < ActiveRecord::Migration[7.1]
  def change
    rename_table :server_events, :actions
  end
end
