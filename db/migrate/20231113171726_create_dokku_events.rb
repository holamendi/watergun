class CreateDokkuEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :dokku_events do |t|
      t.references :org, null: false, foreign_key: true
      t.references :server, null: false, foreign_key: true
      t.references :eventable, null: false, polymorphic: true
      t.references :membership, foreign_key: true
      t.text :command, null: false
      t.string :status, null: false
      t.string :job_id, null: false
      t.datetime :completed_at

      t.timestamps
    end
  end
end
