require "test_helper"
require Rails.root.join("db/migrate/20261018090000_add_environment_intent_to_apps")
require Rails.root.join("db/migrate/20261018091000_add_finalization_evidence_to_server_action_runs")
require Rails.root.join("db/migrate/20261018092000_add_deferred_targets_to_github_events")

class ApiCorrectionMigrationTest < ActiveSupport::TestCase
  test "additive upgrade conservatively preserves populated env run and webhook history" do
    # Resolve encrypted types against the real schema, before the minimal legacy
    # tables. This verifies ciphertext, not the application's callbacks on fake rows.
    payload_type = ServerActionRun.type_for_attribute("payload")
    value_type = EnvVariable.type_for_attribute("value")
    payload = {"dokku_app_id" => "legacy", "set" => {"NAMED" => "migration-only"}, "unset" => ["REMOTE_ONLY"], "restart" => false}
    ciphertext = payload_type.serialize(payload)
    value = value_type.serialize("legacy-env-only")
    connection = ApplicationRecord.connection
    original = connection.schema_search_path
    schema = "api_correction_migration_#{Process.pid}_#{SecureRandom.hex(4)}"
    connection.execute("CREATE SCHEMA #{schema}")
    connection.schema_search_path = schema
    connection.schema_cache.clear!
    connection.create_table(:apps) { |t| t.string :dokku_id }
    connection.create_table(:env_variables) do |t|
      t.string :name
      t.text :value
      t.boolean :internal, default: false
      t.string :status
    end
    connection.create_table(:server_action_runs) do |t|
      t.text :payload
      t.string :action_key
      t.string :status
      t.datetime :remote_completed_at
    end
    connection.create_table(:github_events) do |t|
      t.jsonb :payload
      t.datetime :processed_at
    end
    connection.execute("INSERT INTO apps (id, dokku_id) VALUES (7, 'legacy')")
    connection.execute("INSERT INTO env_variables (id, name, value, internal, status) VALUES (8, 'REMOTE_ONLY', #{connection.quote(value)}, false, 'synced'), (9, 'PROTECTED', #{connection.quote(value)}, true, 'synced')")
    connection.execute("INSERT INTO server_action_runs (id, payload, action_key, status, remote_completed_at) VALUES (10, #{connection.quote(ciphertext)}, 'apps.update_env', 'queued', NULL), (11, #{connection.quote(ciphertext)}, 'apps.destroy', 'success', CURRENT_TIMESTAMP), (12, #{connection.quote(ciphertext)}, 'apps.restart', 'running', NULL)")
    connection.execute("INSERT INTO github_events (id, payload) VALUES (13, '{\"after\":\"legacy-sha\"}')")

    AddEnvironmentIntentToApps.new.migrate(:up)
    AddFinalizationEvidenceToServerActionRuns.new.migrate(:up)
    AddDeferredTargetsToGithubEvents.new.migrate(:up)

    assert_equal 0, connection.select_value("SELECT env_generation FROM apps WHERE id = 7")
    assert_equal [false, false], connection.select_values("SELECT managed FROM env_variables ORDER BY id")
    assert_equal [false, true], connection.select_values("SELECT internal FROM env_variables ORDER BY id")
    assert_equal [value, value], connection.select_values("SELECT value FROM env_variables ORDER BY id")
    assert_equal "legacy-env-only", value_type.deserialize(value)
    assert_equal [nil, nil, nil], connection.select_values("SELECT finalized_at FROM server_action_runs ORDER BY id")
    assert_equal %w[queued success running], connection.select_values("SELECT status FROM server_action_runs ORDER BY id")
    assert_equal [ciphertext, ciphertext, ciphertext], connection.select_values("SELECT payload FROM server_action_runs ORDER BY id")
    assert_equal payload, payload_type.deserialize(connection.select_value("SELECT payload FROM server_action_runs WHERE id = 10"))
    # In particular, migration does NOT rewrite an old accepted destructive unset.
    assert_equal ["REMOTE_ONLY"], payload_type.deserialize(ciphertext).fetch("unset")
    assert connection.select_value("SELECT remote_completed_at IS NOT NULL FROM server_action_runs WHERE id = 11")
    assert_nil connection.select_value("SELECT pending_app_ids FROM github_events WHERE id = 13")
    assert_equal({"after" => "legacy-sha"}, JSON.parse(connection.select_value("SELECT payload FROM github_events WHERE id = 13")))
  ensure
    if connection && original
      connection.schema_search_path = original
      connection.execute("DROP SCHEMA IF EXISTS #{schema} CASCADE") if schema
      connection.schema_cache.clear!
      [App, EnvVariable, ServerActionRun, Github::Event].each(&:reset_column_information)
    end
  end
end
