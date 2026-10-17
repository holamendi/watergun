require "test_helper"

class EnvVariable::MutationServicesTest < ActiveSupport::TestCase
  setup do
    @app = apps(:smol_roda)
  end

  teardown { Current.reset }

  test "all environment services reject foreign account and nonmember context" do
    Current.account = accounts(:other)
    assert_rejected_mutations
    Current.reset
    outsider = User.create!(email: "env-outsider@example.test", password: "test-only-password")
    outsider.memberships.create!(account: accounts(:other))
    Current.user = outsider
    Current.account = @app.account
    assert_rejected_mutations
  end

  test "all environment services reject unavailable app project and server" do
    @app.discard!
    assert_rejected_mutations
    @app.undiscard!
    @app.project.discard!
    assert_rejected_mutations
    @app.project.undiscard!
    @app.update!(status: :deleted)
    assert_rejected_mutations
    @app.update!(status: :pending)
    @app.project.server.update!(status: :deleted)
    assert_rejected_mutations
  end

  test "all environment services reject inconsistent parent and variable ownership" do
    @app.update!(server: servers(:arm))
    assert_rejected_mutations
    @app.update!(server: @app.project.server)
    assert_rejected_mutations(account: accounts(:other))
  end

  test "all environment services reject a discarded variable" do
    assert_rejected_mutations(discarded_at: Time.current)
  end

  test "protected environment variables remain uneditable including persisted protection flags" do
    [{name: "DOKKU_PROTECTED"}, {internal: true}].each do |attributes|
      variable = @app.env_variables.new({name: "PROTECTED", value: "protected-only"}.merge(attributes))
      assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
        refute EnvVariable::CreateEnvVariable.new(variable).save
        assert_includes variable.errors[:base], "Environment variable is not editable"
      end
      variable.save!
      variable.assign_attributes(name: "RENAMED", internal: false, value: "changed-only")
      assert_no_difference "ServerActionRun.count" do
        refute EnvVariable::UpdateEnvVariable.new(variable).save
        assert_raises(ArgumentError) { EnvVariable::DestroyEnvVariable.new(variable).destroy }
      end
      assert_equal "protected-only", variable.reload.value
      assert variable.kept?
      variable.destroy!
    end
  end

  test "service linked variables cannot be edited or deleted even if not marked internal" do
    variable = @app.env_variables.create!(name: "LINKED", value: "linked-only")
    link = ServiceLink.create!(app: @app, service: services(:postgres), env_variable: variable)
    variable.assign_attributes(name: "RENAMED", value: "changed-only")
    assert_no_difference "ServerActionRun.count" do
      refute EnvVariable::UpdateEnvVariable.new(variable).save
      assert_raises(ArgumentError) { EnvVariable::DestroyEnvVariable.new(variable).destroy }
    end
    assert_equal "LINKED", variable.reload.name
    assert_equal "linked-only", variable.value
    assert variable.kept?
    assert link.reload.persisted?
  end

  test "record validation errors remain on the same form bound record" do
    variable = @app.env_variables.new(name: "INVALID-NAME", value: "")
    assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
      refute EnvVariable::CreateEnvVariable.new(variable).save
      assert variable.errors[:name].present?
      assert variable.errors[:value].present?
    end
    variable.assign_attributes(name: "VALID", value: "before-only")
    variable.save!
    variable.assign_attributes(name: "INVALID-NAME", value: "")
    refute EnvVariable::UpdateEnvVariable.new(variable).save
    assert variable.errors[:name].present?
    assert variable.errors[:value].present?
    assert_equal "before-only", variable.reload.value
  end

  test "registered enqueue rejection rolls back creation update and discard" do
    variable = @app.env_variables.create!(name: "BEFORE", value: "before-only")
    candidate = @app.env_variables.new(name: "NEW", value: "new-only")
    ServerAction::Enqueue.stubs(:build).raises(ArgumentError, "Rejected action")
    assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
      assert_raises(ArgumentError) { EnvVariable::CreateEnvVariable.new(candidate).save }
      variable.assign_attributes(name: "AFTER", value: "after-only")
      assert_raises(ArgumentError) { EnvVariable::UpdateEnvVariable.new(variable).save }
      assert_equal "BEFORE", variable.reload.name
      assert_equal "before-only", variable.value
      assert_raises(ArgumentError) { EnvVariable::DestroyEnvVariable.new(variable).destroy }
    end
    assert variable.reload.kept?
  end

  test "unchanged update does not queue work and value only update never unsets the name" do
    variable = @app.env_variables.create!(name: "UNCHANGED", value: "before-only")
    assert_no_difference "ServerActionRun.count" do
      assert EnvVariable::UpdateEnvVariable.new(variable).save
    end
    variable.value = "after-only"
    assert EnvVariable::UpdateEnvVariable.new(variable).save
    run = @app.server_action_runs.order(:id).last.reload
    assert_equal({"UNCHANGED" => "after-only"}, run.payload["set"])
    assert_empty run.payload["unset"]
  end

  private

  def assert_rejected_mutations(**attributes)
    variable = @app.env_variables.new({name: "CONTEXT", value: "context-only"}.merge(attributes))
    assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
      assert_raises(ArgumentError) { EnvVariable::CreateEnvVariable.new(variable).save }
    end
    variable.save!
    variable.value = "changed-only"
    assert_no_difference "ServerActionRun.count" do
      assert_raises(ArgumentError) { EnvVariable::UpdateEnvVariable.new(variable).save }
      assert_raises(ArgumentError) { EnvVariable::DestroyEnvVariable.new(variable).destroy }
    end
    assert_equal "context-only", variable.reload.value
    variable.destroy!
  end
end
