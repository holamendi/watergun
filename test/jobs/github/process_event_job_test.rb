require "test_helper"

class Github::ProcessEventJobTest < ActiveSupport::TestCase
  setup do
    @installation = github_installations(:default)
    @account = @installation.account
    @github_repo = github_repos(:smol_roda)
  end

  test "processes push event and creates deployments" do
    event = Github::Event.create!(
      account: @account,
      installation: @installation,
      headers: {"HTTP_X_GITHUB_EVENT" => "push"},
      payload: {
        "ref" => "refs/heads/main",
        "after" => "abc123def456",
        "repository" => {"full_name" => "holamendi/smol-roda"}
      }
    )

    # Stub the CreateDeployment service to avoid API calls
    Deployment::CreateDeployment.any_instance.stubs(:save!).returns(true)

    Github::ProcessEventJob.perform_now(event)

    assert event.reload.processed?
  end

  test "does not create deployment when webhook_deploy is false" do
    @github_repo.update!(webhook_deploy: false)

    event = Github::Event.create!(
      account: @account,
      installation: @installation,
      headers: {"HTTP_X_GITHUB_EVENT" => "push"},
      payload: {
        "ref" => "refs/heads/main",
        "after" => "abc123def456",
        "repository" => {"full_name" => "holamendi/smol-roda"}
      }
    )

    # Should not call CreateDeployment
    Deployment::CreateDeployment.expects(:new).never

    Github::ProcessEventJob.perform_now(event)

    assert event.reload.processed?
  end

  test "processes installation.created event as no-op" do
    event = Github::Event.create!(
      account: @account,
      installation: @installation,
      headers: {"HTTP_X_GITHUB_EVENT" => "installation"},
      payload: {"action" => "created"}
    )

    Github::ProcessEventJob.perform_now(event)

    assert event.reload.processed?
  end

  test "processes installation.deleted event and destroys installation" do
    event = Github::Event.create!(
      account: @account,
      installation: @installation,
      headers: {"HTTP_X_GITHUB_EVENT" => "installation"},
      payload: {"action" => "deleted"}
    )

    # Verify event is marked as processed before installation is destroyed
    event_id = event.id

    assert_difference -> { Github::Installation.count }, -1 do
      Github::ProcessEventJob.perform_now(event)
    end

    # Event is deleted when installation is destroyed (dependent: :destroy)
    assert_nil Github::Event.find_by(id: event_id)
  end

  test "does not process already processed events" do
    event = github_events(:processed_event)

    # Should return early and not process anything
    Deployment::CreateDeployment.expects(:new).never

    Github::ProcessEventJob.perform_now(event)

    # processed_at should not change
    assert event.reload.processed?
  end

  test "creates multiple deployments for matching repos" do
    app2 = App.create!(
      name: "App 2",
      account: @account,
      server: servers(:amd),
      project: projects(:default),
      dokku_id: "app-2"
    )

    Github::Repo.create!(
      account: @account,
      app: app2,
      repo: "holamendi/smol-roda",
      branch: "main",
      webhook_deploy: true
    )

    event = Github::Event.create!(
      account: @account,
      installation: @installation,
      headers: {"HTTP_X_GITHUB_EVENT" => "push"},
      payload: {
        "ref" => "refs/heads/main",
        "after" => "abc123def456",
        "repository" => {"full_name" => "holamendi/smol-roda"}
      }
    )

    # Stub the CreateDeployment service to avoid API calls
    Deployment::CreateDeployment.any_instance.stubs(:save!).returns(true)

    Github::ProcessEventJob.perform_now(event)

    assert event.reload.processed?
  end

  test "marks event as processed at the end" do
    event = Github::Event.create!(
      account: @account,
      installation: @installation,
      headers: {"HTTP_X_GITHUB_EVENT" => "unknown_event"},
      payload: {}
    )

    refute event.processed?

    Github::ProcessEventJob.perform_now(event)

    assert event.reload.processed?
    assert event.processed_at.present?
  end

  test "deploys apps tracking a branch name that contains slashes" do
    @github_repo.update!(branch: "feature/foo", webhook_deploy: true)

    Deployment::CreateDeployment.expects(:new)
      .with(app: @github_repo.app, commit_sha: "abc123def456")
      .returns(stub(save!: true))

    Github::ProcessEventJob.perform_now(push_event(ref: "refs/heads/feature/foo"))
  end

  test "does not deploy apps tracking main when a branch ending in main is pushed" do
    @github_repo.update!(webhook_deploy: true)

    Deployment::CreateDeployment.expects(:new).never

    event = push_event(ref: "refs/heads/foo/main")
    Github::ProcessEventJob.perform_now(event)

    assert event.reload.processed?
  end

  test "ignores tag pushes" do
    @github_repo.update!(webhook_deploy: true)

    Deployment::CreateDeployment.expects(:new).never

    event = push_event(ref: "refs/tags/main")
    Github::ProcessEventJob.perform_now(event)

    assert event.reload.processed?
  end

  test "ignores branch deletions" do
    @github_repo.update!(webhook_deploy: true)

    Deployment::CreateDeployment.expects(:new).never

    event = push_event(ref: "refs/heads/main", payload: {"deleted" => true, "after" => "0000000000000000000000000000000000000000"})
    Github::ProcessEventJob.perform_now(event)

    assert event.reload.processed?
  end

  private

  def push_event(ref:, payload: {})
    Github::Event.create!(
      account: @account,
      installation: @installation,
      headers: {"HTTP_X_GITHUB_EVENT" => "push"},
      payload: {
        "ref" => ref,
        "after" => "abc123def456",
        "repository" => {"full_name" => "holamendi/smol-roda"}
      }.merge(payload)
    )
  end
end
