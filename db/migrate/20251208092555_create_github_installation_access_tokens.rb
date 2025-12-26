class CreateGithubInstallationAccessTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :github_installation_access_tokens do |t|
      t.references :account, null: false, foreign_key: true
      t.references :github_installation, null: false, foreign_key: true
      t.string :token, null: false
      t.timestamp :expires_at, null: false

      t.timestamps
    end
  end
end
