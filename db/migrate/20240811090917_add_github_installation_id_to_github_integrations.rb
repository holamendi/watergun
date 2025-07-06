class AddGithubInstallationIdToGithubIntegrations < ActiveRecord::Migration[7.2]
  def change
    add_column :github_integrations, :github_installation_id, :string
  end
end
