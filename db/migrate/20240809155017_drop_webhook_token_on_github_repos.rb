class DropWebhookTokenOnGithubRepos < ActiveRecord::Migration[7.2]
  def change
    remove_column :github_repos, :webhook_token
  end
end
