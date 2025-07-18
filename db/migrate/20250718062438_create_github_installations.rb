class CreateGithubInstallations < ActiveRecord::Migration[8.0]
  def change
    create_table :github_installations do |t|
      t.references :github_app, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.integer :installation_id
      t.string :account_login
      t.string :access_token
      t.datetime :expires_at

      t.timestamps
    end
  end
end
