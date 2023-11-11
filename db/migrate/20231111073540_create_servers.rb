class CreateServers < ActiveRecord::Migration[7.1]
  def change
    create_table :servers do |t|
      t.string :provider, null: false
      t.string :name, null: false
      t.string :dokku_token, null: false
      t.string :status, null: false

      t.timestamps
    end
    add_index :servers, :dokku_token, unique: true
  end
end
