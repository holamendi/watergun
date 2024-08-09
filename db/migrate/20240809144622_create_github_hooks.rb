class CreateGithubHooks < ActiveRecord::Migration[7.2]
  def change
    create_table :github_hooks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :github_repo, null: false, foreign_key: true
      t.string :token, null: false
      t.string :secret, null: false
      t.json :events, null: false
      t.integer :github_id

      t.timestamps
    end
    add_index :github_hooks, :token, unique: true
  end
end
