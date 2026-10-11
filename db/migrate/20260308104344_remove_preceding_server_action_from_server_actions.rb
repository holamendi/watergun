class RemovePrecedingServerActionFromServerActions < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :server_actions, :server_actions, column: :preceding_server_action_id
    remove_column :server_actions, :preceding_server_action_id, :integer
  end
end
