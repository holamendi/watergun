class AddGithubIntegrationReferenceToGithubEvents < ActiveRecord::Migration[7.2]
  def change
    add_reference :github_events, :github_integration, null: false, foreign_key: true
  end
end
