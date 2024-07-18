class AddIndexesToServerActionPayload < ActiveRecord::Migration[7.2]
  def change
    execute <<-SQL
      CREATE INDEX index_server_actions_on_dokku_app_id ON server_actions (json_extract(payload, '$.dokku_app_id'));
      CREATE INDEX index_server_actions_on_dokku_service_id ON server_actions (json_extract(payload, '$.dokku_service_id'));
    SQL
  end
end
