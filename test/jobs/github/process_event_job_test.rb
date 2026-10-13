require "test_helper"
require "ostruct"

class Github::ProcessEventJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @installation = github_installations(:default)
    @account = @installation.account
    @github_repo = github_repos(:smol_roda)
  end

  test "deploys the full slash-separated branch name" do
    @github_repo.update!(branch: "feature/payments", webhook_deploy: true)
    event = push_event("refs/heads/feature/payments")
    stub_remote_commit

    assert_difference -> { @github_repo.app.deployments.count }, 1 do
      assert_enqueued_with(job: RunServerActionJob) do
        Github::ProcessEventJob.perform_now(event)
      end
    end

    assert_equal "abc123def456", @github_repo.app.deployments.last.sha
    assert event.reload.processed?
  end

  test "ignores tag pushes even when their ref matches a configured branch" do
    @github_repo.update!(branch: "refs/tags/main", webhook_deploy: true)
    event = push_event("refs/tags/main")
    Github::Installation.any_instance.expects(:api_client).never

    assert_no_difference -> { Deployment.count } do
      assert_no_enqueued_jobs(only: RunServerActionJob) do
        Github::ProcessEventJob.perform_now(event)
      end
    end
    assert event.reload.processed?
  end

  test "ignores deleted branch pushes" do
    @github_repo.update!(webhook_deploy: true)
    event = push_event("refs/heads/main", deleted: true)
    Github::Installation.any_instance.expects(:api_client).never

    assert_no_difference -> { Deployment.count } do
      assert_no_enqueued_jobs(only: RunServerActionJob) do
        Github::ProcessEventJob.perform_now(event)
      end
    end
    assert event.reload.processed?
  end

  test "deploys an ordinary head ref" do
    @github_repo.update!(webhook_deploy: true)
    event = push_event("refs/heads/main")
    stub_remote_commit

    assert_difference -> { @github_repo.app.deployments.count }, 1 do
      Github::ProcessEventJob.perform_now(event)
    end
    assert event.reload.processed?
  end

  test "does not deploy the trailing segment of a slash-separated branch" do
    @github_repo.update!(branch: "payments", webhook_deploy: true)
    event = push_event("refs/heads/feature/payments")
    Github::Installation.any_instance.expects(:api_client).never

    assert_no_difference -> { Deployment.count } do
      Github::ProcessEventJob.perform_now(event)
    end
    assert event.reload.processed?
  end

  test "ignores missing and non-head refs" do
    @github_repo.update!(webhook_deploy: true)
    Github::Installation.any_instance.expects(:api_client).never

    [nil, 123, "main", "refs/tags/main", "refs/pull/1/head"].each do |ref|
      event = push_event(ref)
      assert_no_difference -> { Deployment.count } do
        Github::ProcessEventJob.perform_now(event)
      end
      assert event.reload.processed?
    end
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

  private

  def push_event(ref, deleted: false)
    Github::Event.create!(
      installation: @installation,
      headers: {"HTTP_X_GITHUB_EVENT" => "push"},
      payload: {
        "ref" => ref,
        "deleted" => deleted,
        "after" => "abc123def456",
        "repository" => {"full_name" => @github_repo.repo}
      }
    )
  end

  def stub_remote_commit
    commit = OpenStruct.new(
      sha: "abc123def456",
      author: nil,
      commit: OpenStruct.new(author: nil, message: "Test commit"),
      html_url: "https://github.com/holamendi/smol-roda/commit/abc123def456"
    )
    client = mock("GitHub API")
    client.expects(:commit).with(@github_repo.repo, "abc123def456").returns(commit)
    Github::Installation.any_instance.stubs(:api_client).returns(client)
  end
end
