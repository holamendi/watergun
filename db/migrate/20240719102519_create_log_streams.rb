class CreateLogStreams < ActiveRecord::Migration[7.2]
  def change
    create_table :log_streams do |t|
      t.references :account, null: false, foreign_key: true
      t.references :server, null: false, foreign_key: true
      t.references :log_streamable, polymorphic: true, null: false
      t.string :uuid, null: false
      t.datetime :last_ping_at

      t.timestamps
    end

    add_index :log_streams, :uuid, unique: true
  end
end
