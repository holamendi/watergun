require "test_helper"
require "turbo/broadcastable/test_helper"

class ServerActions::DeployAppTest < ActiveSupport::TestCase
  include SshTestHelper
  include Turbo::Broadcastable::TestHelper

  def setup
    Rails.application.routes.default_url_options[:host] = "localhost"

    @deployment = deployments(:pending_deployment)
    @app = @deployment.app
    @server = @app.server
    @account = @app.account

    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {cmd: "dokku git:auth github.com u #{@account.github_installation.access_token.token}"},
        {cmd: "dokku git:sync smol-roda https://github.com/holamendi/smol-roda.git abc123def456"},
        {cmd: "dokku ps:rebuild smol-roda"}
      ]
    )
  end

  test "deploys app successfully and broadcasts updates" do
    # Verify broadcasts to index page stream
    assert_turbo_stream_broadcasts [@app, :deployments], count: 2 do
      # Verify broadcasts to show page stream
      assert_turbo_stream_broadcasts @deployment, count: 2 do
        @server_action = perform_server_action("apps.deploy", @server, @deployment)
      end
    end

    assert @server_action.success?
    assert @deployment.reload.success?
  end

  test "broadcasts deploying status when deployment starts" do
    streams = capture_turbo_stream_broadcasts [@app, :deployments] do
      capture_turbo_stream_broadcasts @deployment do
        @server_action = perform_server_action("apps.deploy", @server, @deployment)
      end
    end

    # First broadcast should be when status changes to deploying
    first_broadcast = streams.first
    assert_equal "replace", first_broadcast["action"]
    assert_includes first_broadcast["target"], "deployment"
  end

  test "broadcasts to both index and show page streams" do
    show_streams = nil

    index_streams = capture_turbo_stream_broadcasts [@app, :deployments] do
      show_streams = capture_turbo_stream_broadcasts @deployment do
        @server_action = perform_server_action("apps.deploy", @server, @deployment)
      end
    end

    # Both streams should receive 2 broadcasts (deploying + success)
    assert_equal 2, index_streams.count
    assert_equal 2, show_streams.count

    # All should be replace actions
    assert index_streams.all? { it["action"] == "replace" }
    assert show_streams.all? { it["action"] == "replace" }
  end
end
