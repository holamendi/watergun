class RenamefinishedAtOnServerActions < ActiveRecord::Migration[7.1]
  def change
    rename_column :server_actions, :finished_at, :finished_at
  end
end
