class CreateContainerMetrics < ActiveRecord::Migration[7.1]
  def change
    create_table :container_metrics do |t|
      t.references :org, null: false, foreign_key: true
      t.references :container, null: false, foreign_key: true
      t.datetime :timestamp, null: false
      t.float :cpu_percentage, null: false
      t.float :memory_percentage, null: false
      t.string :memory_usage, null: false
      t.string :block_io, null: false
      t.string :network_io, null: false
    end

    add_index :container_metrics, :timestamp
  end
end
