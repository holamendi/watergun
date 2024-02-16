class CreateEnvironmentConfigurations < ActiveRecord::Migration[7.1]
  def change
    create_table :environment_configurations do |t|
      t.references :org, null: false, foreign_key: true
      t.references :environment_configurable, polymorphic: true, null: false
      t.json :variables, default: {}

      t.timestamps
    end
  end
end
