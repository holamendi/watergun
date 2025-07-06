class RenameGithubAccessTokensToGithubIntegrations < ActiveRecord::Migration[7.2]
  def change
    rename_table :github_access_tokens, :github_integrations
    rename_column :github_integrations, :token, :personal_access_token
  end
end
