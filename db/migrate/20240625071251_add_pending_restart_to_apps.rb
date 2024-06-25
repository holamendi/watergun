class AddPendingRestartToApps < ActiveRecord::Migration[7.1]
  def change
    add_column :apps, :pending_restart, :boolean, default: false, null: false
  end
end
