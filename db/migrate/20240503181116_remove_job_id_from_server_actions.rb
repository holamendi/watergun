class RemoveJobIdFromServerActions < ActiveRecord::Migration[7.1]
  def change
    remove_column :server_actions, :job_id, :string
  end
end
