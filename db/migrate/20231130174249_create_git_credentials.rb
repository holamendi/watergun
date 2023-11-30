class CreateGitCredentials < ActiveRecord::Migration[7.1]
  def change
    create_table :git_credentials do |t|
      t.references :org, null: false, foreign_key: true
      t.integer :provider, null: false
      t.string :description
      t.string :personal_access_token, null: false

      t.timestamps
    end
  end
end
