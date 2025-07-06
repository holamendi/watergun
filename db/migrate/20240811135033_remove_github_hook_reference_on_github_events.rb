class RemoveGithubHookReferenceOnGithubEvents < ActiveRecord::Migration[7.2]
  def change
    remove_reference :github_events, :github_hook, null: false, foreign_key: true
  end
end
