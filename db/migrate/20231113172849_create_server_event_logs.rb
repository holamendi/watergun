class CreateServerEventLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :server_event_logs do |t|
      t.references :org, null: false, foreign_key: true
      t.references :server_event, null: false, foreign_key: true
      t.text :content

      t.timestamps
    end

    add_index :server_event_logs, %i[id server_event_id], unique: true
  end
end
