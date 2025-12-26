class CreateGithubInstallations < ActiveRecord::Migration[8.1]
  def change
    create_table :github_installations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :github_app, null: false, foreign_key: true
      t.integer :installation_id
      t.string :login

      t.timestamps
    end
  end
end
