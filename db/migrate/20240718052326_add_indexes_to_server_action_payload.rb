class AddIndexesToServerActionPayload < ActiveRecord::Migration[7.2]
  def change
    add_index :server_actions, "(payload ->> 'dokku_app_id')", name: "index_server_actions_on_dokku_app_id"
    add_index :server_actions, "(payload ->> 'dokku_service_id')", name: "index_server_actions_on_dokku_service_id"
  end
end
