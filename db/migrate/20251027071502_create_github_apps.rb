class CreateGithubApps < ActiveRecord::Migration[8.1]
  def change
    create_table :github_apps do |t|
      t.belongs_to :account, foreign_key: true
      t.integer :app_id, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.string :html_url, null: false
      t.string :client_id, null: false
      t.string :client_secret, null: false
      t.string :pem, null: false
      t.string :webhook_secret, null: false
      t.json :permissions, null: false
      t.json :events, null: false

      t.timestamps
    end
  end
end
