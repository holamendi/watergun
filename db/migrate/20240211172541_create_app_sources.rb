class CreateAppSources < ActiveRecord::Migration[7.1]
  def change
    create_table :app_sources do |t|
      t.references :org, null: false, foreign_key: true
      t.references :app, null: false, foreign_key: true
      t.string :type, null: false
      t.json :data, null: false, default: {}

      t.timestamps
    end
  end
end
