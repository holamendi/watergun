class AddTokenToGithubInstallations < ActiveRecord::Migration[8.0]
  def change
    add_column :github_installations, :token, :string
  end
end
