class AddTokenToGithubIntegrations < ActiveRecord::Migration[7.2]
  def change
    add_column :github_integrations, :token, :string
    add_index :github_integrations, :token, unique: true
  end
end
