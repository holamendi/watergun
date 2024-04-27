class RenameCompletedAtOnServerActions < ActiveRecord::Migration[7.1]
  def change
    rename_column :server_actions, :completed_at, :finished_at
  end
end
