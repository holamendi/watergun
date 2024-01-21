class CreateServices < ActiveRecord::Migration[7.1]
  def change
    create_table :services do |t|
      t.references :org, null: false, foreign_key: true
      t.references :server, null: false, foreign_key: true
      t.string :service_type, null: false
      t.string :name, null: false
      t.string :dokku_name, null: false
      t.string :status, null: false
      t.json :data, null: false, default: {}
      t.datetime :discarded_at

      t.timestamps
    end
  end
end
