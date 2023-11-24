class AddPayloadToServerEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :server_events, :params, :json, null: false, default: {}
  end
end
