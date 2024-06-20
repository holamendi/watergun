class CreateProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :projects do |t|
      t.references :org, null: false, foreign_key: true
      t.references :server, null: false, foreign_key: true
      t.string :name
      t.datetime :discarded_at

      t.timestamps
    end
    add_index :projects, :discarded_at
  end
end
