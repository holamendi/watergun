class AddGithubEventToDeployments < ActiveRecord::Migration[7.2]
  def change
    add_reference :deployments, :github_event, foreign_key: true
  end
end
