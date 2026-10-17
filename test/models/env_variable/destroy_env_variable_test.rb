require "test_helper"

class EnvVariable::DestroyEnvVariableTest < ActiveSupport::TestCase
  test "soft deletes through a plain service and queues only the removed name" do
    variable = apps(:smol_roda).env_variables.create!(name: "REMOVE_ME", value: "removed-secret-only")
    assert defined?(EnvVariable::DestroyEnvVariable), "Environment deletion needs a service object"
    refute EnvVariable::DestroyEnvVariable < ApplicationRecord
    assert_no_difference "EnvVariable.count" do
      assert_difference "ServerActionRun.count", 1 do
        assert EnvVariable::DestroyEnvVariable.new(variable).destroy
      end
    end
    assert variable.reload.discarded?
    run = variable.app.server_action_runs.order(:id).last.reload
    assert_equal ["REMOVE_ME"], run.payload["unset"]
    refute_includes run.payload.to_json, "removed-secret-only"
  end

  test "deletion rejects an unsaved variable without persisting or enqueueing" do
    variable = apps(:smol_roda).env_variables.new(name: "UNSAVED", value: "unsaved-only")
    assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
      assert_raises(ArgumentError) { EnvVariable::DestroyEnvVariable.new(variable).destroy }
    end
  end
end
