class CreateGithubApps < ActiveRecord::Migration[8.0]
  def change
    create_table :github_apps do |t|
      t.references :account, null: false, foreign_key: true
      t.integer :github_id
      t.string :client_id
      t.string :slug
      t.string :url
      t.text :pem
      t.string :webhook_secret
      t.json :permissions
      t.json :events

      t.timestamps
    end
  end
end
