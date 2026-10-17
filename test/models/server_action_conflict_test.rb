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
      assert_raises(ServerAction::Conflict::Error) { @app.env_variables.new(name: "BUSY_TEST", value: "private").save_and_sync }
    end
    assert_raises(ServerAction::Conflict::Error) { @app.update_builder_and_sync("dockerfile") }
    assert_equal "herokuish", @app.reload.builder
  end

  test "ownership changing after initial resolution is revalidated under the acceptance lock" do
    stale = App.find(@app.id)
    App.where(id: @app.id).update_all(account_id: accounts(:other).id)
    assert_no_difference "ServerActionRun.count" do
      assert_raises(ArgumentError) { ServerAction::Enqueue.call(action: "apps.restart", target: stale) }
    end
  end
end
