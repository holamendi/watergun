class RemoveDataAndArgsFromServerActions < ActiveRecord::Migration[7.1]
  def change
    remove_column :server_actions, :data, :json
    remove_column :server_actions, :args, :json
  end
end
