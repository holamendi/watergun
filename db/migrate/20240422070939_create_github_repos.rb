class CreateGithubRepos < ActiveRecord::Migration[7.1]
  def change
    create_table :github_repos do |t|
      t.references :org, null: false, foreign_key: true
      t.references :app, null: false, foreign_key: true
      t.string :repo, null: false
      t.string :branch, null: false
      t.boolean :private, null: false, default: false

      t.timestamps
    end

    add_index :github_repos, [:app_id, :repo], unique: true
  end
end
