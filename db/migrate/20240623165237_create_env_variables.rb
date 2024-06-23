class CreateEnvVariables < ActiveRecord::Migration[7.1]
  def change
    create_table :env_variables do |t|
      t.references :org, null: false, foreign_key: true
      t.references :app, null: false, foreign_key: true
      t.string :key, null: false
      t.text :value, null: false
      t.string :status, null: false
      t.datetime :synced_at
      t.datetime :discarded_at

      t.timestamps
    end

    add_index :env_variables, %i[app_id key], unique: true
    add_index :env_variables, :discarded_at
  end
end
