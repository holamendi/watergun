class AddWebhookDeployToGithubRepo < ActiveRecord::Migration[7.2]
  def change
    add_column :github_repos, :webhook_deploy, :boolean, default: false
  end
end
