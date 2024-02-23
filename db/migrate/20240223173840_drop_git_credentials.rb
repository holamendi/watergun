class DropGitCredentials < ActiveRecord::Migration[7.1]
  def change
    drop_table :git_credentials
  end
end
