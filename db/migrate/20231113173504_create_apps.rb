class CreateApps < ActiveRecord::Migration[7.1]
  def change
    create_table :apps do |t|
      t.references :org, null: false, foreign_key: true
      t.references :server, null: false, foreign_key: true
      t.string :name, null: false
      t.string :dokku_name, null: false

      t.timestamps
    end
  end
end
