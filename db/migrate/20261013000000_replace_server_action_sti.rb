class ReplaceServerActionSti < ActiveRecord::Migration[8.1]
  KEYS = {
    "ServerActions::CreateApp" => "apps.create",
    "ServerActions::CreateDomain" => "apps.add_domain",
    "ServerActions::CreateService" => "services.create",
    "ServerActions::DeployApp" => "apps.deploy",
    "ServerActions::DestroyApp" => "apps.destroy",
    "ServerActions::DestroyDomain" => "apps.remove_domain",
    "ServerActions::DestroyProject" => "projects.destroy",
    "ServerActions::DestroyService" => "services.destroy",
    "ServerActions::EnableSsl" => "apps.enable_ssl",
    "ServerActions::LinkService" => "services.link",
    "ServerActions::MountStorage" => "apps.mount_storage",
    "ServerActions::PullEnv" => "apps.pull_env",
    "ServerActions::RestartApp" => "apps.restart",
    "ServerActions::RestartService" => "services.restart",
    "ServerActions::SetAppBuilder" => "apps.set_builder",
    "ServerActions::UnlinkService" => "services.unlink",
    "ServerActions::UnmountStorage" => "apps.unmount_storage",
    "ServerActions::UpdateEnv" => "apps.update_env"
  }.freeze

  # Independent of the application's renamed model and registry. The legacy
  # encryption type composes with a JSON column, not a text/JSON serializer.
  class LegacyRun < ActiveRecord::Base
    self.table_name = "server_actions"
    self.inheritance_column = :_disabled_sti
  end

  class LegacyEnvironmentRun < LegacyRun
    encrypts :payload, support_unencrypted_data: true
  end

  class EncryptedRun < ActiveRecord::Base
    self.table_name = "server_action_runs"
    serialize :payload, coder: JSON
    encrypts :payload
  end

  def up
    check_quiescent!(:server_actions)
    unknown = select_values("SELECT DISTINCT type FROM server_actions") - KEYS.keys
    raise ActiveRecord::MigrationError, "Unknown historical action types; cutover refused" if unknown.any?

    remove_index :server_actions, name: "index_server_actions_on_dokku_app_id"
    remove_index :server_actions, name: "index_server_actions_on_dokku_service_id"
    add_column :server_actions, :encrypted_payload, :text
    add_column :server_actions, :action_key, :string
    add_column :server_actions, :resource_key, :string
    add_column :server_actions, :enqueued_at, :datetime
    add_column :server_actions, :scheduling_failed_at, :datetime
    LegacyRun.reset_column_information
    LegacyEnvironmentRun.reset_column_information
    LegacyRun.find_each do |row|
      payload = (row.type == "ServerActions::UpdateEnv") ? LegacyEnvironmentRun.find(row.id).payload : row.payload
      if row.type == "ServerActions::UpdateEnv"
        payload = payload.deep_dup
        %w[set unset].each { |key| payload[key] = JSON.parse(payload[key]) if payload[key].is_a?(String) }
      end
      ciphertext = ActiveRecord::Encryption.encryptor.encrypt(JSON.generate(payload || {}))
      row.update_columns(encrypted_payload: ciphertext, action_key: KEYS.fetch(row.type), resource_key: "server:#{row.server_id}",
        scheduling_failed_at: (row.status == "queued") ? Time.current : nil)
    end
    remove_column :server_actions, :payload
    rename_column :server_actions, :encrypted_payload, :payload
    remove_column :server_actions, :type
    rename_column :server_actions, :actionable_type, :target_type
    rename_column :server_actions, :actionable_id, :target_id
    rename_table :server_actions, :server_action_runs
    rename_column :server_action_logs, :server_action_id, :server_action_run_id
    rename_index :server_action_runs, :index_server_events_on_actionable, :index_server_action_runs_on_target
    change_column_null :server_action_runs, :action_key, false
    change_column_null :server_action_runs, :resource_key, false
  end

  def down
    check_quiescent!(:server_action_runs)
    unknown = select_values("SELECT DISTINCT action_key FROM server_action_runs") - KEYS.values
    raise ActiveRecord::MigrationError, "Unknown action keys; rollback refused" if unknown.any?

    add_column :server_action_runs, :legacy_payload, :json
    add_column :server_action_runs, :type, :string
    EncryptedRun.reset_column_information
    EncryptedRun.find_each do |row|
      # Restore the legacy JSON column's encrypted envelope, without quoting it
      # as a JSON string or double-encrypting the ciphertext.
      payload = (row.payload || {}).deep_dup
      old_json = if row.action_key == "apps.update_env"
        %w[set unset].each { |key| payload[key] = JSON.generate(payload[key]) if payload.key?(key) }
        ActiveRecord::Encryption.encryptor.encrypt(JSON.generate(payload))
      else
        JSON.generate(payload)
      end
      connection.execute "UPDATE server_action_runs SET legacy_payload = #{connection.quote(old_json)}::json, type = #{connection.quote(KEYS.key(row.action_key))} WHERE id = #{row.id.to_i}"
    end
    remove_column :server_action_runs, :payload
    rename_column :server_action_runs, :legacy_payload, :payload
    remove_columns :server_action_runs, :action_key, :resource_key, :enqueued_at, :scheduling_failed_at
    rename_column :server_action_logs, :server_action_run_id, :server_action_id
    rename_column :server_action_runs, :target_type, :actionable_type
    rename_column :server_action_runs, :target_id, :actionable_id
    rename_index :server_action_runs, :index_server_action_runs_on_target, :index_server_events_on_actionable
    rename_table :server_action_runs, :server_actions
    add_index :server_actions, "(payload ->> 'dokku_app_id')", name: "index_server_actions_on_dokku_app_id"
    add_index :server_actions, "(payload ->> 'dokku_service_id')", name: "index_server_actions_on_dokku_service_id"
  end

  private

  def check_quiescent!(table)
    if select_value("SELECT 1 FROM #{table} WHERE status = 'running' LIMIT 1")
      raise ActiveRecord::MigrationError, "Running actions exist; stop enqueue sources and drain workers before cutover"
    end
    return unless table_exists?(:solid_queue_jobs)
    if select_value("SELECT 1 FROM solid_queue_jobs WHERE class_name IN ('RunServerActionJob', 'StorageServerActionJob') AND finished_at IS NULL LIMIT 1")
      raise ActiveRecord::MigrationError, "Unfinished action jobs exist; drain or explicitly cancel unstarted action jobs before cutover"
    end
  end
end
