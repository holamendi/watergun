class CreateGithubAccessTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :github_access_tokens do |t|
      t.references :org, null: false, foreign_key: true
      t.string :token, null: false

      t.timestamps
    end
  end
end
