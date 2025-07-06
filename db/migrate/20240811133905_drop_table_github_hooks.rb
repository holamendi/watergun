class DropTableGithubHooks < ActiveRecord::Migration[7.2]
  def change
    drop_table :github_hooks
  end
end
