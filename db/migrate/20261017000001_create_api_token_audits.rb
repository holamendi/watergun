class CreateApiTokenAudits < ActiveRecord::Migration[8.1]
  def change
    create_table :api_token_audits do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :api_token, null: false, foreign_key: true
      t.string :action, null: false
      t.string :request_id, null: false
      t.timestamps
    end
  end
end
