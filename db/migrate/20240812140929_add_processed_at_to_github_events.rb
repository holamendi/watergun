class AddProcessedAtToGithubEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :github_events, :processed_at, :datetime
  end
end
