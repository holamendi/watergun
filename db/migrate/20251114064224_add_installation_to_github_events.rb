class AddInstallationToGithubEvents < ActiveRecord::Migration[8.1]
  def change
    remove_reference :github_events, :github_integration
    add_reference :github_events, :github_installation, null: false
    change_column_null :github_events, :github_installation_id, false
  end
end
