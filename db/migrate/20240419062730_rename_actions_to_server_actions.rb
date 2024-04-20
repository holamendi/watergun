class RenameActionsToServerActions < ActiveRecord::Migration[7.1]
  def change
    rename_table :actions, :server_actions
  end
end
