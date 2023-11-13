class CreateDokkuLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :dokku_logs do |t|
      t.references :org, null: false, foreign_key: true
      t.references :dokku_event, null: false, foreign_key: true
      t.text :content

      t.timestamps
    end

    add_index :dokku_logs, %i[id dokku_event_id], unique: true
  end
end
