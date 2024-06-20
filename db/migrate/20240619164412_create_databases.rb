class CreateDatabases < ActiveRecord::Migration[7.1]
  def change
    create_table :databases do |t|
      t.string :type, null: false
      t.references :org, null: false, foreign_key: true
      t.references :server, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :status, null: false
      t.json :data, default: {}
      t.datetime :discarded_at

      t.timestamps
    end
    add_index :databases, :status
    add_index :databases, :discarded_at
  end
end
