class RevertRolledBackSchemaChanges < ActiveRecord::Migration[8.1]
  # main was reset past #68, #80 and #83 after their migrations had already run in production.
  ROLLED_BACK_VERSIONS = %w[20261013000000 20261017000000 20261017000001 20261017134000]

  ACTION_TYPES = {
    "apps.add_domain" => "ServerActions::CreateDomain",
    "apps.create" => "ServerActions::CreateApp",
    "apps.deploy" => "ServerActions::DeployApp",
    "apps.destroy" => "ServerActions::DestroyApp",
    "apps.enable_ssl" => "ServerActions::EnableSsl",
    "apps.mount_storage" => "ServerActions::MountStorage",
    "apps.pull_env" => "ServerActions::PullEnv",
    "apps.remove_domain" => "ServerActions::DestroyDomain",
    "apps.restart" => "ServerActions::RestartApp",
    "apps.set_builder" => "ServerActions::SetAppBuilder",
    "apps.unmount_storage" => "ServerActions::UnmountStorage",
    "apps.update_env" => "ServerActions::UpdateEnv",
    "projects.destroy" => "ServerActions::DestroyProject",
    "services.create" => "ServerActions::CreateService",
    "services.destroy" => "ServerActions::DestroyService",
    "services.link" => "ServerActions::LinkService",
    "services.restart" => "ServerActions::RestartService",
    "services.unlink" => "ServerActions::UnlinkService"
  }.freeze

  class Run < ActiveRecord::Base
    self.table_name = "server_action_runs"
    serialize :payload, coder: JSON
    encrypts :payload, support_unencrypted_data: true
  end

  def up
    restore_server_actions if table_exists?(:server_action_runs)
    drop_table :api_token_audits if table_exists?(:api_token_audits)
    restore_api_tokens if column_exists?(:api_tokens, :token_digest)
    execute "DELETE FROM schema_migrations WHERE version IN (#{ROLLED_BACK_VERSIONS.map { |v| connection.quote(v) }.join(", ")})"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def restore_server_actions
    if select_value("SELECT 1 FROM server_action_runs WHERE status = 'running' LIMIT 1")
      raise ActiveRecord::MigrationError, "Running server actions exist; drain workers before migrating"
    end
    unknown = select_values("SELECT DISTINCT action_key FROM server_action_runs") - ACTION_TYPES.keys
    raise ActiveRecord::MigrationError, "Unknown action keys: #{unknown.join(", ")}" if unknown.any?

    %i[api_token_id request_id operation_app_id operation_deployment_id idempotency_digest request_fingerprint
      dispatch_pending_at remote_completed_at public_error_code outcome_uncertain].each do |column|
      remove_column :server_action_runs, column, if_exists: true
    end

    add_column :server_action_runs, :legacy_payload, :json, default: {}, null: false
    add_column :server_action_runs, :type, :string
    Run.reset_column_information
    Run.find_each do |run|
      execute "UPDATE server_action_runs SET legacy_payload = #{connection.quote(JSON.generate(run.payload || {}))}::json, " \
        "type = #{connection.quote(ACTION_TYPES.fetch(run.action_key))} WHERE id = #{run.id.to_i}"
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

  def restore_api_tokens
    if select_value("SELECT 1 FROM api_tokens LIMIT 1")
      raise ActiveRecord::MigrationError, "API tokens exist; their secrets can't be restored from digests, revoke them first"
    end

    remove_reference :api_tokens, :user, foreign_key: true, index: true
    remove_columns :api_tokens, :token_digest, :scopes, :revoked_at, :last_used_at
    add_column :api_tokens, :token, :string, null: false
    add_index :api_tokens, :token, unique: true
  end
end
