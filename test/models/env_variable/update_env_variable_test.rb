require "test_helper"

class EnvVariable::UpdateEnvVariableTest < ActiveSupport::TestCase
  test "renames through a plain service with replacement and prior name removal" do
    variable = apps(:smol_roda).env_variables.create!(name: "BEFORE", value: "before-only")
    variable.assign_attributes(name: "AFTER", value: "after-only")
    assert defined?(EnvVariable::UpdateEnvVariable), "Environment updates need a service object"
    refute EnvVariable::UpdateEnvVariable < ApplicationRecord
    assert_difference "ServerActionRun.count", 1 do
      assert EnvVariable::UpdateEnvVariable.new(variable).save
    end
    assert_equal "AFTER", variable.reload.name
    run = variable.app.server_action_runs.order(:id).last.reload
    assert_equal({"AFTER" => "after-only"}, run.payload["set"])
    assert_equal ["BEFORE"], run.payload["unset"]
  end

  test "update rejects an unsaved variable without persisting or enqueueing" do
    variable = apps(:smol_roda).env_variables.new(name: "UNSAVED", value: "unsaved-only")
    assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
      assert_raises(ArgumentError) { EnvVariable::UpdateEnvVariable.new(variable).save }
    end
  end
end
