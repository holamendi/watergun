class CreateDomains < ActiveRecord::Migration[7.1]
  def change
    create_table :domains do |t|
      t.references :org, null: false, foreign_key: true
      t.references :app, null: false, foreign_key: true
      t.string :hostname, null: false
      t.integer :status, null: false
      t.boolean :ssl_enabled, null: false, default: false
      t.datetime :discarded_at

      t.timestamps
    end
    add_index :domains, :status
    add_index :domains, :discarded_at
  end
end
