class AddRunningAtToServerEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :server_events, :running_at, :datetime
  end
end
