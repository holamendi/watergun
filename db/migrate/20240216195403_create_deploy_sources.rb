class CreateDeploySources < ActiveRecord::Migration[7.1]
  def change
    create_table :deploy_sources do |t|
      t.references :org, null: false, foreign_key: true
      t.references :app, null: false, foreign_key: true
      t.string :type
      t.boolean :active
      t.json :data

      t.timestamps
    end
  end
end
