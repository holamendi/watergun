require "test_helper"

class Api::V1::EnvWritesTest < ActionDispatch::IntegrationTest
  include SshTestHelper

  self.use_transactional_tests = false

  setup do
    project = projects(:default)
    @app = project.apps.create!(server: project.server, name: "env-write", status: :active)
    @app.server.update!(status: :active)
    @token = ApiToken.create!(account: @app.account, user: users(:bobby), scopes: ["env:write", "apps:read", "operations:read"])
    @secret = @token.token
  end

  teardown do
    runs = ServerActionRun.where(target: @app)
    ServerActionLog.where(server_action_run_id: runs.select(:id)).delete_all
    runs.delete_all
    @app.destroy!
    ApiTokenAudit.where(api_token_id: @token.id).delete_all
    @token.destroy!
  end

  test "merge durably accepts one encrypted batch and actual job applies set then unset without restart" do
    @app.env_variables.create!(name: "OLD", value: "before")
    @app.env_variables.create!(name: "KEEP", value: "untouched")
    value = "http-env-write-secret"
    assert_difference "ServerActionRun.count", 1 do
      write({mode: "merge", values: {NEW: value, OLD: nil, MISSING: nil}})
      assert_response :accepted
    end
    operation = json_response.fetch("operation")
    assert_equal "app.env", operation.fetch("kind")
    assert_equal "queued", operation.fetch("status")
    run = ServerActionRun.find(operation.fetch("id"))
    assert_equal "apps.update_env", run.action_key
    assert_equal({"NEW" => value}, run.payload.fetch("set"))
    assert_equal ["OLD"], run.payload.fetch("unset")
    assert_equal ["KEEP", "NEW"], @app.env_variables.kept.order(:name).pluck(:name)
    assert @app.reload.pending_restart?
    raw = ServerActionRun.connection.select_value("SELECT payload FROM server_action_runs WHERE id = #{run.id.to_i}")
    refute_includes raw, value
    refute_includes response.body, value
    assert run.enqueued_at || run.dispatch_pending_at
    require "json_schemer"
    contract = JSONSchemer.openapi(YAML.safe_load_file(Rails.root.join("docs/api/openapi.yml"), aliases: true), regexp_resolver: "ecma")
    assert_empty contract.schema("OperationEnvelope").validate(json_response).to_a
    row = ServerActionRun.connection.select_value("SELECT row_to_json(server_action_runs)::text FROM server_action_runs WHERE id = #{run.id.to_i}")
    refute_includes row, value
    refute_includes row, Base64.strict_encode64(value)
    mock_ssh_session(host: @app.server.public_ip, user: SshKey::USER, port: @app.server.ssh_port, private_key: @app.server.ssh_key.private_key,
      commands: [{cmd: Dokku::Config::SetCommand.new(app: @app.dokku_id, env: {"NEW" => value}).cmd, stdout: value, stderr: Base64.strict_encode64(value)},
        {cmd: "dokku config:unset #{@app.dokku_id} OLD --no-restart"}], ordered: true)
    RunServerActionJob.perform_now(run.id, run.resource_key)
    assert run.reload.success?
    refute_includes run.log.reload.ssh_commands.to_json, value
    refute_includes run.log.ssh_commands.to_json, Base64.strict_encode64(value)
    get "/api/v1/apps/#{@app.id}", headers: auth("read")
    assert_response :ok
    assert_equal ["KEEP", "NEW"], json_response.dig("app", "env_names")
    refute_includes response.body, value
  end

  test "empty strings set values while null deletes and merge omission preserves" do
    @app.env_variables.create!(name: "KEEP", value: "kept")
    write({mode: "merge", values: {EMPTY: ""}})
    assert_response :accepted
    run = ServerActionRun.find(json_response.dig("operation", "id"))
    assert_equal "", @app.env_variables.kept.find_by!(name: "EMPTY").value
    assert_equal({"EMPTY" => ""}, run.payload.fetch("set"))
    assert_empty run.payload.fetch("unset")
    assert_equal "kept", @app.env_variables.kept.find_by!(name: "KEEP").value
    run.update!(status: :success)
    write({mode: "merge", values: {EMPTY: nil}}, key: "delete-empty")
    assert_response :accepted
    assert_nil @app.env_variables.kept.find_by(name: "EMPTY")
    assert_equal ["EMPTY"], ServerActionRun.find(json_response.dig("operation", "id")).payload.fetch("unset")
  end

  test "replacement affects only locally managed keys and empty merge is a durable no-op" do
    managed = @app.env_variables.create!(name: "MANAGED", value: "old", managed: true)
    internal = @app.env_variables.create!(name: "SYSTEM", value: "private", internal: true)
    reserved = @app.env_variables.create!(name: "DOKKU_SYSTEM", value: "private")
    linked = @app.env_variables.create!(name: "DATABASE_URL", value: "private")
    ServiceLink.create!(app: @app, service: services(:postgres), env_variable: linked)
    write({mode: "merge", values: {}})
    assert_response :accepted
    run = ServerActionRun.find(json_response.dig("operation", "id"))
    assert_empty run.payload.fetch("set")
    assert_empty run.payload.fetch("unset")
    refute @app.reload.pending_restart?
    run.update!(status: :success)
    write({mode: "replace", values: {}}, key: "replace")
    assert_response :accepted
    run = ServerActionRun.find(json_response.dig("operation", "id"))
    assert_equal [managed.name], run.payload.fetch("unset")
    assert managed.reload.discarded?
    [internal, reserved, linked].each { |record| refute record.reload.discarded? }
    assert_equal 1, ServiceLink.where(env_variable: linked).count
    assert @app.reload.pending_restart?
  end

  test "request logs and actual notification subscribers filter arbitrary env values even on invalid input" do
    value = "unusual-env-logging-sentinel"
    output = StringIO.new
    old_logger, old_record_logger = Rails.logger, ActiveRecord::Base.logger
    Rails.logger = ActiveRecord::Base.logger = ActiveSupport::Logger.new(output)
    captured = []
    subscriber = ActiveSupport::Notifications.subscribe(/action_controller/) { |*args| captured << args.last.slice(:params, :exception, :exception_object).inspect }
    write({mode: "merge", values: {GREETING: value}})
    assert_response :accepted
    write({mode: "merge", values: {BAD: [value]}}, key: "bad-logging")
    assert_response :unprocessable_content
    [output.string, captured.join, response.body, ApiTokenAudit.all.map(&:attributes).to_json].each do |text|
      refute_includes text, value
      refute_includes text, @secret
    end
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    Rails.logger, ActiveRecord::Base.logger = old_logger, old_record_logger if old_logger
  end

  test "malformed JSON does not expose raw body or parser causes through framework boundary" do
    value = "malformed-env-sentinel"
    output = StringIO.new
    old_logger = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(output)
    put "/api/v1/apps/#{@app.id}/env", params: %({"mode":"merge","values":{"GREETING":"#{value}"), headers: auth("malformed").merge("CONTENT_TYPE" => "application/json"), env: {"action_dispatch.logger" => Rails.logger}
    assert_response :bad_request
    assert_equal "invalid_request", json_response.dig("error", "code")
    refute_includes response.body, value
    refute_includes output.string, value
  ensure
    Rails.logger = old_logger if old_logger
  end

  test "invalid mixed batches and protected names cannot mutate any local rows or enqueue work" do
    record = @app.env_variables.create!(name: "EXISTING", value: "original")
    internal = @app.env_variables.create!(name: "SYSTEM", value: "private", internal: true)
    linked = @app.env_variables.create!(name: "DATABASE_URL", value: "private")
    ServiceLink.create!(app: @app, service: services(:postgres), env_variable: linked)
    invalid = [{mode: "merge", values: {"OK" => "secret", "bad-name" => "no"}},
      {mode: "replace", values: {OK: "secret", SYSTEM: nil}},
      {mode: "replace", values: {OK: "secret", DATABASE_URL: "overwrite"}},
      {mode: "merge", values: {DOKKU_FOO: "no"}}, {mode: "merge", values: {DOKKU_FOO: nil}},
      {mode: "merge", values: {"X" * 129 => "no"}}, {mode: "merge", values: {"1BAD" => "no"}},
      {mode: "merge", values: {BAD: "nul\0secret"}}, {mode: "merge", values: {BAD: "s" * 16_385}},
      {mode: "merge", values: 101.times.to_h { |i| ["V#{i}", "s"] }},
      {mode: "merge", values: {BAD: 1}}, {mode: "merge", values: {BAD: true}},
      {mode: "merge", values: {BAD: {nested: "secret"}}}, {mode: "merge", values: []},
      {mode: "merge", values: nil}, {mode: "oops", values: {}}, {mode: nil, values: {}}]
    invalid.each_with_index do |body, index|
      assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
        write(body, key: "invalid-#{index}")
        assert_response :unprocessable_content
        assert_equal "validation_failed", json_response.dig("error", "code")
      end
      assert_equal "original", record.reload.value
      [record, internal, linked].each { |row| refute row.reload.discarded? }
      refute @app.reload.pending_restart?
      refute_includes response.body, "secret"
    end
  end

  test "HTTP envelopes duplicates media query and byte limits reject without writes" do
    assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
      patch "/api/v1/apps/#{@app.id}/env", params: {mode: "merge", values: {}}, as: :json, headers: auth("patch")
      assert_response :not_found
      [{values: {}}, {mode: "merge"}, {mode: "merge", values: {}, extra: "secret"}, [], nil].each do |body|
        write(body)
        assert_response :bad_request
      end
      ['{"mode":"merge","values":{"DUP":"one","DUP":"two"}}',
        '{"mode":"merge","mode":"replace","values":{}}'].each do |body|
        put "/api/v1/apps/#{@app.id}/env", params: body, headers: auth("duplicate").merge("CONTENT_TYPE" => "application/json")
        assert_response :bad_request
      end
      put "/api/v1/apps/#{@app.id}/env", params: "x" * 65_537, headers: auth("large").merge("CONTENT_TYPE" => "application/json")
      assert_response :content_too_large
      put "/api/v1/apps/#{@app.id}/env", params: "not json", headers: auth("media").merge("CONTENT_TYPE" => "text/plain")
      assert_response :unsupported_media_type
      put "/api/v1/apps/#{@app.id}/env?mode=replace", params: {mode: "merge", values: {}}, as: :json, headers: auth("query")
      assert_response :bad_request
      write({mode: "merge", values: {}}, key: nil)
      assert_response :bad_request
    end
  end

  test "canonical retries return original operation without extra writes and changed input conflicts" do
    write({mode: "merge", values: {B: "two", A: "one"}})
    assert_response :accepted
    original = json_response.fetch("operation")
    run = ServerActionRun.find(original.fetch("id"))
    assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
      write({values: {A: "one", B: "two"}, mode: "merge"})
      assert_response :accepted
      assert_equal original, json_response.fetch("operation")
      write({mode: "merge", values: {B: "two", A: ""}})
      assert_response :conflict
      assert_equal "idempotency_conflict", json_response.dig("error", "code")
      run.update!(status: :success)
      write({mode: "merge", values: {B: "two", A: "one"}})
      assert_response :accepted
      assert_equal run.id, json_response.dig("operation", "id")
    end
    refute_equal Digest::SHA256.hexdigest(JSON.generate({mode: "merge", values: {A: "one", B: "two"}})), run.request_fingerprint
    assert_equal 64, run.request_fingerprint.length
  end

  test "read only scope expiry revocation membership tenant and wrong parent are denied" do
    original_scopes = @token.scopes
    cases = [{read_only: true}, {scopes: ["apps:write"]}, {expires_at: 1.minute.ago}, {revoked_at: Time.current}]
    cases.each_with_index do |attributes, index|
      @token.update!(attributes)
      assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
        write({mode: "merge", values: {DENIED: "no"}}, key: "deny-#{index}")
        assert_response (index < 2) ? :forbidden : :unauthorized
      end
      @token.update!(read_only: false, scopes: original_scopes, expires_at: 1.day.from_now, revoked_at: nil)
    end
    membership = Membership.find_by!(account: @token.account, user: @token.user)
    attributes = membership.attributes.except("id", "created_at", "updated_at")
    membership.delete
    write({mode: "merge", values: {DENIED: "no"}})
    assert_response :unauthorized
    Membership.create!(attributes)
    @app.update_columns(account_id: accounts(:other).id)
    write({mode: "merge", values: {DENIED: "no"}})
    assert_response :not_found
    @app.update_columns(account_id: @token.account_id)
    project = @app.project
    project.update_columns(account_id: Account.where.not(id: @token.account_id).first!.id)
    write({mode: "merge", values: {DENIED: "no"}})
    assert_response :not_found
    project.update_columns(account_id: @token.account_id)
    assert_empty @app.env_variables.kept
  end

  test "queue outage is accepted durably while failure to commit batch rolls back all writes" do
    existing = @app.env_variables.create!(name: "EXISTING", value: "original", managed: true)
    with_public_acceptance_storage_failure(@token) do
      assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
        write({mode: "replace", values: {NEW: "secret"}})
        assert_response :service_unavailable
      end
    end
    assert_equal "original", existing.reload.value
    refute existing.discarded?
    refute @app.reload.pending_restart?
    refute_includes response.body, "secret"

    RunServerActionJob.any_instance.stubs(:enqueue).raises(ActiveJob::EnqueueError, "secret-queue")
    write({mode: "replace", values: {NEW: "secret"}})
    assert_response :accepted
    run = ServerActionRun.find(json_response.dig("operation", "id"))
    assert run.dispatch_pending_at
    assert run.scheduling_failed_at
    assert existing.reload.discarded?
    RunServerActionJob.any_instance.unstub(:enqueue)
    ServerAction::Recovery.call
    assert run.reload.enqueued_at
    assert_nil run.dispatch_pending_at
  end

  test "unset failure filters both streams and never reports remote success or blindly replays" do
    value = "deleted-env-secret"
    @app.env_variables.create!(name: "DELETE_ME", value: value)
    write({mode: "merge", values: {DELETE_ME: nil}})
    assert_response :accepted
    run = ServerActionRun.find(json_response.dig("operation", "id"))
    mock_ssh_session(host: @app.server.public_ip, user: SshKey::USER, port: @app.server.ssh_port, private_key: @app.server.ssh_key.private_key,
      commands: [{cmd: "dokku config:unset #{@app.dokku_id} DELETE_ME --no-restart", exit_code: 1, stdout: value, stderr: Base64.strict_encode64(value)}])
    RunServerActionJob.perform_now(run.id, run.resource_key)
    assert run.reload.failure?
    assert_equal "remote_failed", run.public_error_code
    refute_includes run.log.reload.ssh_commands.to_json, value
    refute_includes run.log.ssh_commands.to_json, Base64.strict_encode64(value)
    assert_no_difference "ServerActionRun.count" do
      write({mode: "merge", values: {DELETE_ME: nil}})
      assert_response :accepted
      assert_equal "failed", json_response.dig("operation", "status")
    end
  end

  test "boundary names values and key count are supported and replacement executes empty set and omitted deletions" do
    @app.env_variables.create!(name: "OMITTED", value: "old", managed: true)
    @app.env_variables.create!(name: "UNMANAGED_SYSTEM", value: "private", internal: true)
    name = "N" * 128
    value = "v" * 16_384
    write({mode: "replace", values: {name => value, "EMPTY" => "", "ABSENT" => nil}})
    assert_response :accepted
    run = ServerActionRun.find(json_response.dig("operation", "id"))
    assert_equal ["OMITTED"], run.payload.fetch("unset")
    assert_equal({name => value, "EMPTY" => ""}, run.payload.fetch("set"))
    mock_ssh_session(host: @app.server.public_ip, user: SshKey::USER, port: @app.server.ssh_port, private_key: @app.server.ssh_key.private_key,
      commands: [{cmd: Dokku::Config::SetCommand.new(app: @app.dokku_id, env: {name => value, "EMPTY" => ""}).cmd},
        {cmd: "dokku config:unset #{@app.dokku_id} OMITTED --no-restart"}], ordered: true)
    RunServerActionJob.perform_now(run.id, run.resource_key)
    assert run.reload.success?
    write({mode: "merge", values: 100.times.to_h { |index| ["K#{index}", "v"] }}, key: "hundred")
    assert_response :accepted
    assert_equal 100, ServerActionRun.find(json_response.dig("operation", "id")).payload.fetch("set").size
  end

  test "real database write failure midway through batch restores every record and dispatch obligation" do
    existing = @app.env_variables.create!(name: "EXISTING", value: "before")
    connection = EnvVariable.connection
    connection.execute(<<~SQL)
      CREATE FUNCTION reject_env_batch_test() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.app_id = #{@app.id.to_i} AND NEW.name = 'REJECT' THEN
          RAISE EXCEPTION 'batch write rejected';
        END IF;
        RETURN NEW;
      END; $$;
      CREATE TRIGGER reject_env_batch_test BEFORE INSERT ON env_variables
      FOR EACH ROW EXECUTE FUNCTION reject_env_batch_test();
    SQL
    assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
      write({mode: "replace", values: {EXISTING: "after", FIRST: "secret", REJECT: "secret"}})
      assert_response :service_unavailable
    end
    assert_equal "before", existing.reload.value
    refute existing.discarded?
    refute @app.reload.pending_restart?
    assert_equal ["EXISTING"], @app.env_variables.kept.pluck(:name)
  ensure
    connection&.execute("DROP TRIGGER IF EXISTS reject_env_batch_test ON env_variables; DROP FUNCTION IF EXISTS reject_env_batch_test()")
  end

  test "missing inaccessible discarded wrong server and prerequisite targets fail without mutation" do
    assert_no_difference "ServerActionRun.count" do
      ["999999999", "0", "-1", "#{@app.id}bad"].each do |id|
        put "/api/v1/apps/#{id}/env", params: {mode: "merge", values: {}}, as: :json, headers: auth("bad-target")
        assert_response :not_found
      end
      @app.discard!
      write({mode: "merge", values: {}})
      assert_response :not_found
      @app.undiscard!
      @app.update_columns(server_id: servers(:arm).id)
      write({mode: "merge", values: {}})
      assert_response :not_found
      @app.update_columns(server_id: @app.project.server_id)
      @app.server.reload.update!(status: :pending)
      write({mode: "merge", values: {}})
      assert_response :conflict
      assert_equal "prerequisite_missing", json_response.dig("error", "code")
    end
  end

  private

  def write(body, key: "write")
    put "/api/v1/apps/#{@app.id}/env", params: body, as: :json, headers: auth(key)
  end

  def auth(key) = {"Authorization" => "Bearer #{@secret}", "Idempotency-Key" => key}
end
