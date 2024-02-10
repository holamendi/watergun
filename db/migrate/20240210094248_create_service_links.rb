class CreateServiceLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :service_links do |t|
      t.references :org, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :app, null: false, foreign_key: true
      t.string :status

      t.timestamps
    end

    add_index :service_links, %i[service_id app_id], unique: true
  end
end
