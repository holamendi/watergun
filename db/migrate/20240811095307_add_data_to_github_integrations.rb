class AddDataToGithubIntegrations < ActiveRecord::Migration[7.2]
  def change
    add_column :github_integrations, :data, :json
  end
end
