class CreateDokkuUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :dokku_users do |t|
      t.references :org, null: false, foreign_key: true
      t.references :server, null: false, foreign_key: true
      t.text :private_key, null: false

      t.timestamps
    end

    add_index :dokku_users, :private_key, unique: true
    add_index :dokku_users, %i[id server_id], unique: true
  end
end
