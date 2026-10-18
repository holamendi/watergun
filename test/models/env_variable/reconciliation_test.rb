require "test_helper"

class EnvVariable::ReconciliationTest < ActiveSupport::TestCase
  setup { @app = apps(:domain_test_app) }

  test "replace preserves imported and ambiguous historical keys" do
    historical = @app.env_variables.create!(name: "HISTORICAL", value: "unknown", status: :synced)
    pull([{"name" => "HISTORICAL", "value" => "unknown"}, {"name" => "REMOTE_ONLY", "value" => "remote"}])

    write = EnvVariable::WriteEnvVariables.new(app: @app, mode: "replace", values: {})
    assert write.save

    assert historical.reload.kept?
    assert @app.env_variables.kept.exists?(name: "REMOTE_ONLY")
    assert_empty write.server_action_run.payload.fetch("unset")
  end

  test "old export cannot delete a newly accepted desired key" do
    pull([]) do
      assert EnvVariable::WriteEnvVariables.new(app: @app, mode: "merge", values: {"NEW_VALUE" => "desired"}).save
    end

    desired = @app.env_variables.kept.find_by(name: "NEW_VALUE")
    assert desired, "old export deleted pending desired intent"
    assert_equal "desired", desired.value
    assert desired.pending?
  end

  test "explicit batch write claims a key and subsequent pull preserves its provenance" do
    variable = @app.env_variables.create!(name: "CLAIMED", value: "remote", status: :synced)
    refute variable.managed?
    write = EnvVariable::WriteEnvVariables.new(app: @app, mode: "merge", values: {"CLAIMED" => "desired"})
    assert write.save
    assert variable.reload.managed?
    pull([{"name" => "CLAIMED", "value" => "desired"}])
    assert variable.reload.managed?
    assert variable.synced?
  end

  test "explicit UI write claims an ambiguous key without claiming its neighbours" do
    variable = @app.env_variables.create!(name: "CLAIMED", value: "unknown", status: :synced)
    untouched = @app.env_variables.create!(name: "UNKNOWN", value: "unknown", status: :synced)
    assert EnvVariable::UpdateEnvVariable.new(variable).save
    assert variable.reload.managed?
    refute untouched.reload.managed?
    write = EnvVariable::WriteEnvVariables.new(app: @app, mode: "replace", values: {})
    assert write.save
    assert_equal ["CLAIMED"], write.server_action_run.payload.fetch("unset")
    assert untouched.reload.kept?
  end

  test "pull preserves protected rows and never claims remote service values" do
    variable = @app.env_variables.create!(name: "SERVICE_URL", value: "temp", internal: true)
    link = ServiceLink.create!(app: @app, service: services(:postgres), env_variable: variable)
    pull([{"name" => "SERVICE_URL", "value" => "service-dsn"}])
    assert_equal "service-dsn", variable.reload.value
    assert variable.internal?
    refute variable.managed?
    pull([])
    assert variable.reload.kept?
    assert link.reload.persisted?
  end

  test "an explicit unchanged UI claim invalidates an older missing observation" do
    variable = @app.env_variables.create!(name: "CLAIMED_DURING_PULL", value: "desired", status: :synced)
    pull([]) { assert EnvVariable::UpdateEnvVariable.new(variable).save }
    assert EnvVariable.exists?(variable.id), "old observation erased a newer ownership claim"
    assert variable.reload.managed?
  end

  test "pull reconciles a reclaimed name rather than its historical tombstone" do
    @app.env_variables.create!(name: "RECLAIMED", value: "old", discarded_at: 1.day.ago)
    current = @app.env_variables.create!(name: "RECLAIMED", value: "desired", managed: true)
    pull([{"name" => "RECLAIMED", "value" => "desired"}])
    assert current.reload.synced?
    assert current.managed?
    assert_equal "desired", current.value
  end

  test "old export cannot overwrite a newer desired value" do
    variable = @app.env_variables.create!(name: "VALUE", value: "old", status: :synced)
    pull([{"name" => "VALUE", "value" => "old"}]) do
      variable.value = "desired"
      assert EnvVariable::UpdateEnvVariable.new(variable).save
    end

    assert_equal "desired", variable.reload.value
  end

  test "stale UI update cannot overwrite a newly protected row" do
    variable = @app.env_variables.create!(name: "PROTECTED_LATER", value: "original")
    variable.service_link # Cache the earlier absence, as a form request may do.
    EnvVariable.find(variable.id).update!(internal: true, value: "service-owned")
    variable.assign_attributes(name: "RENAMED", internal: false, value: "ui")

    assert_no_difference "ServerActionRun.count" do
      refute EnvVariable::UpdateEnvVariable.new(variable).save
    end
    assert_equal "service-owned", variable.reload.value
    assert variable.internal?
  end

  test "stale UI destroy cannot discard a newly linked row" do
    variable = @app.env_variables.create!(name: "LINKED_LATER", value: "original")
    variable.service_link
    link = ServiceLink.create!(app: @app, service: services(:postgres), env_variable: EnvVariable.find(variable.id))

    assert_no_difference "ServerActionRun.count" do
      assert_raises(ArgumentError) { EnvVariable::DestroyEnvVariable.new(variable).destroy }
    end
    assert variable.reload.kept?
    assert link.reload.persisted?
  end

  private

  def pull(values, &during_export)
    run = ServerAction::Enqueue.build(action: "apps.pull_env", target: @app)
    transport = Object.new
    transport.define_singleton_method(:execute!) do |_command|
      during_export&.call
      Struct.new(:parsed_output).new(values)
    end
    ServerActions::PullEnv.new(run).execute!(transport)
  end
end
