class AddWebhookTokenToGithubRepos < ActiveRecord::Migration[7.2]
  def change
    add_column :github_repos, :webhook_token, :string
    add_index :github_repos, :webhook_token
  end
end
