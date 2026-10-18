require "test_helper"

class Github::DeferredPushTest < ActiveSupport::TestCase
  include SshTestHelper
  include ActiveJob::TestHelper

  setup do
    @busy = apps(:smol_roda)
    @repo = @busy.github_repo
    @repo.update!(webhook_deploy: true)
    @busy.server.update!(cpu_type: :x86)
    @idle = @busy.project.apps.create!(server: @busy.server, name: "idle-webhook", status: :active)
    @idle.create_github_repo!(account: @busy.account, repo: @repo.repo, branch: @repo.branch, webhook_deploy: true)
    @event = Github::Event.create!(installation: @busy.account.github_installation,
      headers: {"HTTP_X_GITHUB_EVENT" => "push"},
      payload: {"ref" => "refs/heads/#{@repo.branch}", "after" => "a" * 40, "repository" => {"full_name" => @repo.repo}})
    commit = stub(sha: "a" * 40, author: nil, commit: stub(author: nil, message: "deferred push"), html_url: "https://example.test/commit")
    Github::Installation.any_instance.stubs(:api_client).returns(stub(commit: commit))
  end

  test "a busy target is deferred durably while idle targets progress without duplicate acceptance" do
    restart = ServerAction::Enqueue.call(action: "apps.restart", target: @busy)

    assert_enqueued_with(job: Github::ProcessEventJob, args: [@event]) do
      Github::ProcessEventJob.perform_now(@event)
    end

    refute @event.reload.processed?
    idle_deployment = @idle.deployments.find_by!(github_event: @event)
    assert_equal "a" * 40, idle_deployment.sha
    assert_equal "github_webhook", idle_deployment.source
    assert idle_deployment.server_action_run.persisted?
    assert_empty @busy.deployments.where(github_event: @event)
    assert_no_difference ["Deployment.count", "ServerActionRun.count"] do
      Github::ProcessEventJob.perform_now(@event)
    end

    mock_ssh_session(host: @busy.server.public_ip, user: SshKey::USER, port: @busy.server.ssh_port,
      private_key: @busy.server.ssh_key.private_key, commands: [{cmd: "dokku ps:restart #{@busy.dokku_id}"}])
    ServerAction::Runner.new(restart).call
    assert @busy.reload.active?
    assert_difference ["Deployment.count", "ServerActionRun.count"], 1 do
      Github::ProcessEventJob.perform_now(@event)
    end
    assert @event.reload.processed?
    assert_equal idle_deployment.id, @idle.deployments.find_by!(github_event: @event).id
    assert_equal 1, @busy.deployments.where(github_event: @event).count
    assert_no_difference ["Deployment.count", "ServerActionRun.count"] do
      Github::ProcessEventJob.perform_now(@event)
    end
  end
end
