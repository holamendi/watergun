require "test_helper"
require Rails.root.join("db/migrate/20261013000000_replace_server_action_sti")

class ServerActionMigrationTest < ActiveSupport::TestCase
  test "populated cutover preserves all action keys, history, logs and unrelated records" do
    with_legacy_schema do |connection|
      payload = {"dokku_app_id" => "test-only-app", "set" => {"API_KEY" => "test-only-secret"}.to_json, "unset" => ["OLD"].to_json, "restart" => false}
      ids = ReplaceServerActionSti::KEYS.keys.map.with_index do |type, index|
        model = (type == "ServerActions::UpdateEnv") ? ReplaceServerActionSti::LegacyEnvironmentRun : ReplaceServerActionSti::LegacyRun
        row = model.create!(id: index + 1, type: type, account_id: 1, server_id: 1, user_id: 1,
          actionable_type: "App", actionable_id: 1, status: "success", payload: payload)
        connection.execute("INSERT INTO server_action_logs (account_id, server_action_id, ssh_commands) VALUES (1, #{row.id}, '[]')")
        row.id
      end
      counts = unrelated_counts(connection)
      migrate(:up)
      assert_equal counts, unrelated_counts(connection)
      assert_equal 18, connection.select_value("SELECT COUNT(*) FROM server_action_runs").to_i
      assert_equal 18, connection.select_value("SELECT COUNT(*) FROM server_action_logs").to_i
      assert_equal ids, connection.select_values("SELECT server_action_run_id FROM server_action_logs ORDER BY server_action_run_id").map(&:to_i)
      assert_equal ReplaceServerActionSti::KEYS.values.sort, connection.select_values("SELECT action_key FROM server_action_runs ORDER BY action_key")
      raw = connection.select_values("SELECT payload FROM server_action_runs")
      raw.each { |value| refute_includes value, "test-only-secret" }
      env = ReplaceServerActionSti::EncryptedRun.find(ids.last)
      assert_equal({"API_KEY" => "test-only-secret"}, env.payload.fetch("set"))
      assert_equal ["OLD"], env.payload.fetch("unset")
      assert_equal false, env.payload.fetch("restart")
      assert_equal "App", env.target_type
      assert_equal 1, env.target_id
      assert_equal "server:1", env.resource_key
      migrate(:down)
      assert_equal counts, unrelated_counts(connection)
      assert_equal 18, connection.select_value("SELECT COUNT(*) FROM server_actions").to_i
      legacy = ReplaceServerActionSti::LegacyEnvironmentRun.find(ids.last)
      assert_equal payload, legacy.payload
      refute_includes connection.select_value("SELECT payload FROM server_actions WHERE id = #{ids.last}").to_s, "test-only-secret"
      migrate(:up)
      assert_equal({"API_KEY" => "test-only-secret"}, ReplaceServerActionSti::EncryptedRun.find(ids.last).payload.fetch("set"))
    end
  end

  test "unknown legacy types refuse cutover without losing records" do
    with_legacy_schema do |connection|
      connection.execute("INSERT INTO server_actions (type, account_id, server_id, status, payload) VALUES ('UnknownAction', 1, 1, 'success', '{}')")
      assert_raises(ActiveRecord::MigrationError) { migrate(:up) }
      assert_equal 1, connection.select_value("SELECT COUNT(*) FROM server_actions").to_i
      refute connection.table_exists?(:server_action_runs)
    end
  end

  test "running actions and unfinished legacy jobs refuse cutover without deleting unrelated jobs" do
    with_legacy_schema do |connection|
      connection.execute("INSERT INTO solid_queue_jobs (class_name, arguments) VALUES ('UnrelatedJob', '{}')")
      connection.execute("INSERT INTO solid_queue_jobs (class_name, arguments) VALUES ('RunServerActionJob', '{}')")
      assert_raises(ActiveRecord::MigrationError) { migrate(:up) }
      assert_equal 2, connection.select_value("SELECT COUNT(*) FROM solid_queue_jobs").to_i
      connection.execute("UPDATE solid_queue_jobs SET finished_at = CURRENT_TIMESTAMP WHERE class_name = 'RunServerActionJob'")
      connection.execute("INSERT INTO server_actions (type, account_id, server_id, status, payload) VALUES ('ServerActions::RestartApp', 1, 1, 'running', '{}')")
      assert_raises(ActiveRecord::MigrationError) { migrate(:up) }
      connection.execute("UPDATE server_actions SET status = 'success'")
      migrate(:up)
      assert_equal 2, connection.select_value("SELECT COUNT(*) FROM solid_queue_jobs").to_i
    end
  end

  private

  def migrate(direction)
    ActiveRecord::Base.connection.transaction(requires_new: true) { ReplaceServerActionSti.new.migrate(direction) }
    [ReplaceServerActionSti::LegacyRun, ReplaceServerActionSti::LegacyEnvironmentRun, ReplaceServerActionSti::EncryptedRun].each(&:reset_column_information)
  end

  def unrelated_counts(connection)
    %w[accounts users servers projects apps services].to_h { |table| [table, connection.select_value("SELECT COUNT(*) FROM #{table}").to_i] }
  end

  def with_legacy_schema
    connection = ActiveRecord::Base.connection
    original = connection.schema_search_path
    schema = "action_migration_#{Process.pid}_#{SecureRandom.hex(4)}"
    connection.execute("CREATE SCHEMA #{schema}")
    connection.schema_search_path = schema
    connection.schema_cache.clear!
    %w[accounts users servers projects apps services].each do |table|
      connection.create_table(table) { |t| t.string :name }
      connection.execute("INSERT INTO #{table} (id, name) VALUES (1, 'preserved')")
    end
    connection.create_table(:server_actions) do |t|
      t.integer :account_id
      t.integer :server_id
      t.integer :user_id
      t.integer :actionable_id
      t.string :actionable_type
      t.string :type
      t.string :status
      t.json :payload
    end
    connection.add_index :server_actions, "(payload ->> 'dokku_app_id')", name: "index_server_actions_on_dokku_app_id"
    connection.add_index :server_actions, "(payload ->> 'dokku_service_id')", name: "index_server_actions_on_dokku_service_id"
    connection.add_index :server_actions, [:actionable_type, :actionable_id], name: "index_server_events_on_actionable"
    %w[accounts servers users].each { |table| connection.add_foreign_key(:server_actions, table) }
    connection.create_table(:server_action_logs) do |t|
      t.integer :account_id
      t.integer :server_action_id, null: false
      t.json :ssh_commands
    end
    connection.add_foreign_key :server_action_logs, :server_actions
    connection.create_table(:solid_queue_jobs) do |t|
      t.string :class_name
      t.text :arguments
      t.datetime :finished_at
    end
    [ReplaceServerActionSti::LegacyRun, ReplaceServerActionSti::LegacyEnvironmentRun].each(&:reset_column_information)
    yield connection
  ensure
    connection.schema_search_path = original
    connection.execute("DROP SCHEMA IF EXISTS #{schema} CASCADE")
    connection.schema_cache.clear!
    [ReplaceServerActionSti::LegacyRun, ReplaceServerActionSti::LegacyEnvironmentRun, ReplaceServerActionSti::EncryptedRun, ServerActionRun].each(&:reset_column_information)
  end
end
