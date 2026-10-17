require "test_helper"

class ServerActionConflictTest < ActiveSupport::TestCase
  setup { @app = apps(:domain_test_app) }

  test "UI and API pending or running lifecycle work exclude every other lifecycle mutation" do
    %w[queued running].each do |status|
      %w[apps.restart apps.destroy apps.update_env apps.set_builder].each do |first|
        run = ServerAction::Enqueue.call(action: first, target: @app)
        run.update!(status: status)
        %w[apps.restart apps.destroy apps.update_env apps.set_builder].each do |second|
          assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: second, target: @app) }
        end
        run.update!(status: :success, finished_at: Time.current)
      end
    end
  end

  test "a pending deployment conflicts with restart and an independent app is usable" do
    deployment = deployments(:pending_deployment)
    deployment.update!(app: @app, account: @app.account)
    run = ServerAction::Enqueue.call(action: "apps.deploy", target: deployment)
    assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: "apps.restart", target: @app) }
    other = @app.project.apps.create!(name: "independent-conflict-test")
    assert ServerAction::Enqueue.call(action: "apps.restart", target: other).persisted?
    run.update!(status: :error, outcome_uncertain: true)
    assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: "apps.destroy", target: @app) }
  end

  test "conflicting domain env and builder preparation rolls back local changes" do
    @app.update!(builder: :herokuish)
    ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    assert_no_difference "EnvVariable.count" do
      assert_raises(ServerAction::Conflict::Error) { EnvVariable::CreateEnvVariable.new(@app.env_variables.new(name: "BUSY_TEST", value: "private")).save }
    end
    assert_raises(ServerAction::Conflict::Error) { App::SetAppBuilder.new(app: @app, builder: "dockerfile").save }
    assert_equal "herokuish", @app.reload.builder
    variable = @app.env_variables.create!(name: "BUSY_EXISTING", value: "original")
    variable.value = "changed"
    assert_raises(ServerAction::Conflict::Error) { EnvVariable::UpdateEnvVariable.new(variable).save }
    assert_equal "original", variable.reload.value
    assert_raises(ServerAction::Conflict::Error) { EnvVariable::DestroyEnvVariable.new(variable).destroy }
    assert variable.reload.kept?
  end

  test "project deletion cannot bypass pending running or uncertain child app exclusion" do
    project = Project.create!(server: @app.server, account: @app.account, name: "isolated-project-exclusion")
    @app = project.apps.create!(server: project.server, name: "child-app")
    %w[queued running error].each do |status|
      run = ServerAction::Enqueue.call(action: "apps.restart", target: @app)
      run.update!(status: status, outcome_uncertain: status == "error")
      assert_raises(ServerAction::Conflict::Error) { Project::DestroyProject.new(@app.project).destroy }
      assert @app.project.reload.kept?
      run.update!(status: :success, outcome_uncertain: false)
    end
  end

  test "queued project deletion rejects new app work and legacy project work cannot run over a busy app" do
    project = Project.create!(server: @app.server, account: @app.account, name: "isolated-project-queue")
    @app = project.apps.create!(server: project.server, name: "child-app")
    project_run = ServerAction::Enqueue.call(action: "projects.destroy", target: @app.project)
    assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: "apps.restart", target: @app) }
    project_run.update!(status: :success)
    ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    project_run.update!(status: :queued)
    Net::SSH.expects(:start).never
    assert_raises(ServerAction::Conflict::Error) { ServerAction::Runner.new(project_run).call }
    assert project_run.reload.error?
  end

  test "shared env batch excludes create deploy restart delete and project deletion in both directions" do
    project = Project.create!(server: @app.server, account: @app.account, name: "batch-conflicts")
    @app = project.apps.create!(name: "batch-conflicts")
    deployment = deployments(:pending_deployment)
    deployment.update!(app: @app, account: @app.account)
    %w[queued running].each do |status|
      %w[apps.create apps.deploy apps.restart apps.destroy apps.update_env].each do |action|
        target = (action == "apps.deploy") ? deployment : @app
        run = ServerAction::Enqueue.call(action: action, target: target)
        run.update!(status: status)
        assert_raises(ServerAction::Conflict::Error) do
          EnvVariable::WriteEnvVariables.new(app: @app, mode: "replace", values: {"BLOCKED" => "no"}).save
        end
        assert_empty @app.env_variables.kept
        run.update!(status: :success)
      end
    end
    command = EnvVariable::WriteEnvVariables.new(app: @app, mode: "merge", values: {"WINNER" => "yes"})
    assert command.save
    %w[apps.create apps.deploy apps.restart apps.destroy].each do |action|
      target = (action == "apps.deploy") ? deployment : @app
      assert_raises(ServerAction::Conflict::Error) { ServerAction::Enqueue.call(action: action, target: target) }
    end
    assert_raises(ServerAction::Conflict::Error) { Project::DestroyProject.new(@app.project).destroy }
    independent = @app.project.apps.create!(name: "independent-batch")
    assert EnvVariable::WriteEnvVariables.new(app: independent, mode: "merge", values: {}).save
    command.server_action_run.update!(status: :success)
    independent.server_action_runs.update_all(status: :success)
    ServerAction::Enqueue.call(action: "projects.destroy", target: @app.project)
    assert_raises(ServerAction::Conflict::Error) { EnvVariable::WriteEnvVariables.new(app: @app, mode: "merge", values: {}).save }
  end

  test "ownership changing after initial resolution is revalidated under the acceptance lock" do
    stale = App.find(@app.id)
    App.where(id: @app.id).update_all(account_id: accounts(:other).id)
    assert_no_difference "ServerActionRun.count" do
      assert_raises(ArgumentError) { ServerAction::Enqueue.call(action: "apps.restart", target: stale) }
    end
  end
end
