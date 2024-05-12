class AddDependentServerActionIdToServerActions < ActiveRecord::Migration[7.1]
  def change
    add_reference :server_actions, :preceding_server_action, foreign_key: {to_table: :server_actions}, type: :integer, index: true
  end
end
