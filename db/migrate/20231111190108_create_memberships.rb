class CreateMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :org, null: false, foreign_key: true

      t.timestamps
    end

    add_index :memberships, [:user_id, :org_id], unique: true
  end
end
