require "test_helper"
require_relative "../../../app/models/ssh/session"

class ServerActions::DestroyAppTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include SshTestHelper

  test "failed remote deletion leaves app visible for recovery" do
    app = apps(:domain_test_app)
    server = app.server
    mock_ssh_session(host: server.public_ip, user: SshKey::USER,
      port: server.ssh_port, private_key: server.ssh_key.private_key,
      commands: [{cmd: "dokku apps:destroy --force domain-test-app", exit_code: 1, stderr: "Deletion refused"}])
    action = App::DestroyApp.new(app).destroy

    assert_no_difference -> { App.count } do
      RunServerActionJob.perform_now(action.id, action.resource_key)
    end

    assert app.reload.kept?
    assert app.error?
    assert action.reload.failure?
    assert action.finished_at
    assert_equal 1, action.log.ssh_commands.first.fetch("exit_code")
    assert_equal "Deletion refused", action.log.ssh_commands.first.fetch("output").first.fetch("data")
  end

  test "deleting is a temporary app status" do
    app = apps(:domain_test_app)
    app.deleting!

    assert app.temporary_status?
  end

  test "job destroys app after successful remote deletion" do
    app = apps(:domain_test_app)
    server = app.server
    transport = mock
    transport.expects(:exec!).with do |command, options|
      assert_equal "dokku apps:destroy --force domain-test-app", command
      assert app.reload.deleting?
      options[:status][:exit_code] = 0
      true
    end.yields(nil, :stdout, "Deleted app")
    transport.expects(:loop).at_least_once
    Net::SSH.expects(:start).with(server.public_ip, SshKey::USER,
      port: server.ssh_port, key_data: [server.ssh_key.private_key],
      keys_only: true, non_interactive: true).yields(transport)
    action = App::DestroyApp.new(app).destroy

    assert_difference -> { App.count }, -1 do
      RunServerActionJob.perform_now(action.id, action.resource_key)
    end

    assert action.reload.success?
    assert action.finished_at
    assert_nil App.find_by(id: app.id)
    assert_equal "Deleted app", action.log.ssh_commands.first.fetch("output").first.fetch("data")
  end
end
