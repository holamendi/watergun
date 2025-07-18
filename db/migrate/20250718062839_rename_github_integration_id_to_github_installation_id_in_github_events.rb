class RenameGithubIntegrationIdToGithubInstallationIdInGithubEvents < ActiveRecord::Migration[8.0]
  def change
    rename_column :github_events, :github_integration_id, :github_installation_id
  end
end
