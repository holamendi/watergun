class CreateApiTokens < ActiveRecord::Migration[7.1]
  def change
    create_table :api_tokens do |t|
      t.references :org, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.boolean :read_only, null: false, default: false
      t.datetime :expires_at, null: false

      t.timestamps
    end
    add_index :api_tokens, :token, unique: true
  end
end
