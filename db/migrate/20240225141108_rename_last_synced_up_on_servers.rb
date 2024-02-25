class RenameLastSyncedUpOnServers < ActiveRecord::Migration[7.1]
  def change
    rename_column :servers, :last_synced_up, :last_synced_at
  end
end
