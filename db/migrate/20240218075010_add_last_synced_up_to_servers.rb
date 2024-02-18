class AddLastSyncedUpToServers < ActiveRecord::Migration[7.1]
  def change
    add_column :servers, :last_synced_up, :datetime
    add_index :servers, :last_synced_up
  end
end
