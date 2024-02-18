class CreateContainers < ActiveRecord::Migration[7.1]
  def change
    create_table :containers do |t|
      t.references :org, null: false, foreign_key: true
      t.references :server, null: false, foreign_key: true
      t.references :containerizable, polymorphic: true, null: false
      t.string :status, null: false
      t.string :cid, null: false
      t.string :name, null: false
      t.float :cpu_percentage, null: false
      t.float :memory_percentage, null: false
      t.string :memory_usage, null: false
      t.string :block_io, null: false
      t.string :network_io, null: false
      t.datetime :last_synced_at, null: false
      t.datetime :stopped_at

      t.timestamps
    end

    add_index :containers, :status
    add_index :containers, :cid
  end
end
