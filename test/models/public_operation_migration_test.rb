require "test_helper"
require Rails.root.join("db/migrate/20261017134000_add_public_operation_acceptance_to_server_action_runs")

class PublicOperationMigrationTest < ActiveSupport::TestCase
  test "populated upgrade preserves encrypted history and enforces atomic key uniqueness" do
    # Exercise the same cold model-schema boundary regardless of test order.
    ServerActionRun.reset_column_information
    connection = ActiveRecord::Base.connection
    original = connection.schema_search_path
    # Resolve the real encrypted type before exposing a deliberately minimal
    # historical table to this connection. It has no runtime enum columns.
    payload_type = ServerActionRun.type_for_attribute("payload")
    payload = {"set" => {"PRIVATE_KEY" => "migration-test-secret"}}
    ciphertext = payload_type.serialize(payload)
    schema = "public_operation_migration_#{Process.pid}_#{SecureRandom.hex(4)}"
    connection.execute("CREATE SCHEMA #{schema}")
    connection.schema_search_path = schema
    connection.schema_cache.clear!
    connection.create_table(:server_action_runs) do |t|
      t.bigint :account_id
      t.string :action_key
      t.string :status
      t.text :payload
    end
    connection.execute("INSERT INTO server_action_runs (id, account_id, action_key, status, payload) VALUES (7, 1, 'apps.update_env', 'success', #{connection.quote(ciphertext)})")
    AddPublicOperationAcceptanceToServerActionRuns.new.migrate(:up)
    row = connection.select_one("SELECT * FROM server_action_runs WHERE id = 7")
    assert_equal ciphertext, row.fetch("payload")
    assert_equal payload, payload_type.deserialize(row.fetch("payload"))
    refute_includes row.fetch("payload"), "migration-test-secret"
    assert_equal "success", row.fetch("status")
    assert_equal false, row.fetch("outcome_uncertain")
    assert_nil row.fetch("request_id")
    assert_nil row.fetch("dispatch_pending_at")
    connection.execute("UPDATE server_action_runs SET api_token_id = 2, idempotency_digest = 'digest', request_fingerprint = 'fingerprint' WHERE id = 7")
    assert_raises(ActiveRecord::RecordNotUnique) do
      connection.transaction(requires_new: true) do
        connection.execute("INSERT INTO server_action_runs (account_id, api_token_id, idempotency_digest) VALUES (1, 2, 'digest')")
      end
    end
    connection.execute("INSERT INTO server_action_runs (account_id, api_token_id, idempotency_digest) VALUES (2, 2, 'digest'), (1, 3, 'digest'), (1, NULL, NULL), (1, NULL, NULL)")
    assert_equal 5, connection.select_value("SELECT COUNT(*) FROM server_action_runs")
    AddPublicOperationAcceptanceToServerActionRuns.new.migrate(:down)
    assert_equal ciphertext, connection.select_value("SELECT payload FROM server_action_runs WHERE id = 7")
  ensure
    connection.schema_search_path = original
    connection.execute("DROP SCHEMA IF EXISTS #{schema} CASCADE")
    connection.schema_cache.clear!
    ServerActionRun.reset_column_information
  end
end
