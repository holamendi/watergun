class RemoveGithubInstallationIdFromGithubIntegrations < ActiveRecord::Migration[7.2]
  def change
    remove_column :github_integrations, :github_installation_id, :string
  end
end
