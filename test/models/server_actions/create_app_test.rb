require "test_helper"

class ServerActions::CreateAppTest < ActiveSupport::TestCase
  include SshTestHelper

  def setup
    @app = apps(:smol_roda)
    @server = @app.server
    @project = @app.project
    @app.pending!

    mock_ssh_session(
      host: @server.public_ip,
      user: SshKey::USER,
      port: @server.ssh_port,
      private_key: @server.ssh_key.private_key,
      commands: [
        {
          cmd: "dokku apps:create smol-roda"
        },
        {
          cmd: "dokku domains:report smol-roda",
          stdout: file_fixture("dokku/domains/report_command_output.txt").read
        }
      ]
    )
  end

  test "creates a dokku app and links it to existing project services" do
    assert_difference(
      -> { @app.domains.count } => 1,
      -> { @app.services.count } => @project.services.count
    ) do
      @server_action = perform_server_action("apps.create", @app.server, @app)
    end

    # creates dokku app
    assert @server_action.success?
    assert @app.reload.active?

    # creates default domain
    domain = @app.domains.first
    assert_equal "smol-roda.local.watergun.dev", domain.hostname
    assert domain.active?
    assert domain.is_default?

    # creates service links for existing project services
    assert_equal @project.services, @app.services

    # schedules server actions to link services
    @app.service_links.each do |service_link|
      assert_server_action_scheduled(
        "services.link",
        server: @server,
        target: service_link,
        payload: {
          dokku_app_id: @app.dokku_id,
          dokku_service_id: service_link.service.dokku_id,
          service_type: service_link.service.service_type,
          env_name: service_link.env_variable.name
        }
      )
    end
  end
end
