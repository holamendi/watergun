class DropGithubIntegrations < ActiveRecord::Migration[8.0]
  def up
    # Since this is not in production, delete any github_events that reference old integrations
    execute "DELETE FROM github_events"
    
    # First add the foreign key constraint for github_events -> github_installations
    add_foreign_key :github_events, :github_installations, column: :github_installation_id
    
    # Disable foreign key checks for dropping the old table
    connection.execute("PRAGMA foreign_keys = OFF")
    drop_table :github_integrations
    connection.execute("PRAGMA foreign_keys = ON")
  end

  def down
    # This is a destructive migration - can't be reversed
    raise ActiveRecord::IrreversibleMigration
  end
end
