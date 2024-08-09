class CreateGithubEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :github_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :github_hook, null: false, foreign_key: true
      t.json :headers
      t.json :payload

      t.timestamps
    end
  end
end
