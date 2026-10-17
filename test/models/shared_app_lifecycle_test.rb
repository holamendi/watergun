require "test_helper"

class SharedAppLifecycleTest < ActiveSupport::TestCase
  setup do
    @app = apps(:smol_roda)
    @project = @app.project
  end

  test "deployment and run creation roll back together on enqueue validation failure" do
    ServerAction::Enqueue.stubs(:build).raises(ArgumentError, "Rejected action")
    VCR.use_cassette("github/valid_commit") do
      assert_no_difference ["Deployment.count", "ServerActionRun.count"] do
        assert_raises(ArgumentError) { Deployment::CreateDeployment.new(app: @app).save! }
      end
    end
  end

  test "first release actions reject discarded app and project state" do
    @app.discard!
    %w[apps.restart apps.destroy apps.update_env apps.set_builder].each do |key|
      assert_raises(ArgumentError) { ServerAction::Enqueue.call(action: key, target: @app) }
    end
    @app.undiscard!
    @project.discard!
    assert_raises(ArgumentError) { App::DestroyApp.new(@app).destroy }
  end

  test "current account cannot enqueue a mutation for another account" do
    Current.account = Account.create!(name: "Other account")
    assert_no_difference "ServerActionRun.count" do
      assert_raises(ArgumentError) { ServerAction::Enqueue.call(action: "apps.restart", target: @app) }
    end
  ensure
    Current.reset
  end

  test "create reports missing installation without contacting GitHub" do
    Github::Installation.where(account: @project.account).destroy_all
    command = App::CreateApp.new(project: @project, repo: "example/app", branch: "main")
    assert_no_difference ["App.count", "ServerActionRun.count"] do
      refute command.save
    end
    assert_includes command.errors[:base], "GitHub installation is required"
  end

  test "create reports missing project without contacting GitHub" do
    command = App::CreateApp.new(repo: "example/app", branch: "main")
    refute command.save
    assert command.errors[:project].present?
  end

  test "deployment reports missing repository without creating records" do
    command = Deployment::CreateDeployment.new(app: apps(:domain_test_app))
    assert_no_difference ["Deployment.count", "ServerActionRun.count"] do
      assert_raises(ActiveModel::ValidationError) { command.save! }
    end
    assert_includes command.errors[:base], "GitHub repository is required"
  end

  test "deployment validates the configured branch commit even without an explicit sha" do
    client = mock
    client.expects(:branch).with(@app.github_repo.repo, @app.github_repo.branch).raises(Octokit::NotFound)
    Github::Installation.any_instance.stubs(:api_client).returns(client)
    command = Deployment::CreateDeployment.new(app: @app)
    assert_raises(ActiveModel::ValidationError) { command.save! }
    assert_includes command.errors[:commit_sha], "does not exist"
  end

  test "shared environment save rejects mismatched variable ownership" do
    variable = @app.env_variables.new(account: Account.create!(name: "Other"), name: "EXAMPLE", value: "example-only")
    assert_no_difference ["EnvVariable.count", "ServerActionRun.count"] do
      assert_raises(ArgumentError) { variable.save_and_sync }
    end
  end

  test "shared environment save cannot edit internal or reserved variables" do
    [
      {name: "EXAMPLE", internal: true},
      {name: "DOKKU_EXAMPLE", internal: false}
    ].each do |attributes|
      variable = @app.env_variables.create!(**attributes, value: "example-only")
      variable.assign_attributes(name: "RENAMED", value: "new-only")
      refute variable.save_and_sync
      assert_equal "example-only", variable.reload.value
      assert_raises(ArgumentError) { variable.discard_and_sync! }
      assert variable.reload.kept?
    end
  end

  test "shared create and deployment reject current-account mismatch before GitHub lookup" do
    Current.account = accounts(:other)
    Github::Installation.any_instance.expects(:api_client).never
    assert_no_difference ["App.count", "Deployment.count", "ServerActionRun.count"] do
      assert_raises(ArgumentError) do
        App::CreateApp.new(project: @project, repo: "example/app", branch: "main").save
      end
      assert_raises(ArgumentError) { Deployment::CreateDeployment.new(app: @app).save! }
    end
  ensure
    Current.reset
  end

  test "API context uses the same callable boundary and resource key without a browser session" do
    Current.account = @app.account
    Current.source = "api_v1"
    Current.user = nil
    variable = @app.env_variables.new(name: "SHARED_SECRET", value: "shared-secret-only")
    assert variable.save_and_sync
    run = @app.server_action_runs.where(action_key: "apps.update_env").order(:id).last
    assert run.reload.api_v1?
    assert_nil run.user
    assert_equal "app:#{@app.id}", run.resource_key
    assert_equal({"SHARED_SECRET" => "shared-secret-only"}, run.payload["set"])
    raw = ServerActionRun.connection.select_value("SELECT payload FROM server_action_runs WHERE id = #{run.id.to_i}")
    refute_includes raw, "shared-secret-only"
  ensure
    Current.reset
  end

  test "stale project state rejects a queued mutation before SSH and records error" do
    run = ServerAction::Enqueue.call(action: "apps.restart", target: @app)
    @project.discard!
    Net::SSH.expects(:start).never
    assert_raises(ArgumentError) { ServerAction::Runner.new(run).call }
    assert run.reload.error?
    assert run.finished_at
    assert @app.reload.pending?
  end

  test "create enqueue validation failure rolls back app repository and run" do
    ServerAction::Enqueue.stubs(:build).raises(ArgumentError, "Rejected action")
    VCR.use_cassette("github/valid_repo_and_branch") do
      assert_no_difference ["App.count", "Github::Repo.count", "ServerActionRun.count"] do
        assert_raises(ArgumentError) do
          App::CreateApp.new(project: @project, repo: "holamendi/smol-roda", branch: "main").save
        end
      end
    end
  end

  test "deleted app or server and inconsistent parent server cannot enqueue app actions" do
    @app.update!(status: :deleted)
    assert_raises(ArgumentError) { ServerAction::Enqueue.call(action: "apps.restart", target: @app) }
    @app.update!(status: :pending)
    @app.server.update!(status: :deleted)
    assert_raises(ArgumentError) { App::DestroyApp.new(@app).destroy }
    @app.server.update!(status: :pending)
    @app.update!(server: servers(:arm))
    assert_raises(ArgumentError) { ServerAction::Enqueue.call(action: "apps.restart", target: @app) }
  end

  test "pending app and server remain supported while a nonmember actor is rejected" do
    @app.server.update!(status: :pending)
    @app.update!(status: :pending)
    run = ServerAction::Enqueue.build(action: "apps.restart", target: @app)
    assert_equal @app, run.target
    outsider = User.create!(email: "shared-outsider@example.test", password: "test-only-password")
    assert_raises(ArgumentError) do
      ServerAction::Enqueue.call(action: "apps.restart", target: @app, user: outsider)
    end
  end

  test "API deployment pins repo and resolved branch HEAD with source context" do
    Current.account = @app.account
    Current.source = "api_v1"
    Current.user = nil
    deployment = VCR.use_cassette("github/valid_commit") do
      Deployment::CreateDeployment.new(app: @app).save!
    end
    run = deployment.server_action_run
    original_repo = deployment.repo
    original_sha = deployment.sha
    @app.github_repo.update!(repo: "changed/repository", branch: "changed/branch")
    assert_equal original_repo, deployment.reload.repo
    assert_equal original_sha, deployment.sha
    assert_equal original_repo, run.reload.payload["repo"]
    assert_equal original_sha, run.payload["sha"]
    assert deployment.api_v1?
    assert run.api_v1?
    assert_nil deployment.user
    assert_nil run.user
  ensure
    Current.reset
  end
end
