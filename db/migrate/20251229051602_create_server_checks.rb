class CreateServerChecks < ActiveRecord::Migration[8.1]
  def change
    create_table :server_checks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :server, null: false, foreign_key: true
      t.float :cpu_usage, null: false
      t.float :memory_usage, null: false
      t.bigint :memory_used_bytes
      t.bigint :memory_total_bytes
      t.float :disk_usage
      t.bigint :disk_used_bytes
      t.bigint :disk_total_bytes
      t.float :load_average
      t.datetime :timestamp, null: false

      t.timestamps
    end

    add_index :server_checks, [:server_id, :timestamp]
    add_index :server_checks, :timestamp
  end
end
