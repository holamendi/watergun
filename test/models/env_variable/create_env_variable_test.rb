require "test_helper"

class EnvVariable::CreateEnvVariableTest < ActiveSupport::TestCase
  test "creates an environment variable and encrypted registered run through a plain service" do
    variable = apps(:smol_roda).env_variables.new(name: "SERVICE_SECRET", value: "service-secret-only")
    assert defined?(EnvVariable::CreateEnvVariable), "Environment creation needs a service object"
    refute EnvVariable::CreateEnvVariable < ApplicationRecord
    assert_difference ["EnvVariable.count", "ServerActionRun.count"], 1 do
      assert EnvVariable::CreateEnvVariable.new(variable).save
    end
    run = variable.app.server_action_runs.order(:id).last.reload
    assert_equal "apps.update_env", run.action_key
    assert_equal({"SERVICE_SECRET" => "service-secret-only"}, run.payload["set"])
    assert_empty run.payload["unset"]
    raw = ServerActionRun.connection.select_value("SELECT payload FROM server_action_runs WHERE id = #{run.id.to_i}")
    refute_includes raw, "service-secret-only"
  end

  test "creation rejects an already persisted variable without enqueueing" do
    variable = apps(:smol_roda).env_variables.create!(name: "EXISTING", value: "existing-only")
    assert_no_difference "ServerActionRun.count" do
      assert_raises(ArgumentError) { EnvVariable::CreateEnvVariable.new(variable).save }
    end
  end
end
