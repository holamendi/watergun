class CreateStorageMounts < ActiveRecord::Migration[8.2]
  def change
    create_table :storage_mounts do |t|
      t.references :account
      t.references :app
      t.string :host_path, null: false
      t.string :container_path, null: false
      t.string :chown
      t.string :status, default: "pending"
      t.datetime :discarded_at
      t.timestamps
    end

    add_index :storage_mounts, :discarded_at
    add_index :storage_mounts, [:app_id, :container_path], unique: true
  end
end
