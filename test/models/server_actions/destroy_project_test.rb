require "test_helper"

require Rails.root.join("app/models/ssh/session")

class ServerActions::DestroyProjectTest < ActiveSupport::TestCase
  include SshTestHelper

  test "destroys a project on its owning server through the job" do
    project = projects(:default)
    server = project.server
    commands = project.apps.kept.map { |app| {cmd: Dokku::Apps::DestroyCommand.new(app: app.dokku_id).cmd} }
    commands += project.services.kept.map { |service| {cmd: Dokku::Services::DestroyCommand.new(plugin: service.service_type, name: service.dokku_id).cmd} }
    mock_ssh_session(host: server.public_ip, user: SshKey::USER, port: server.ssh_port,
      private_key: server.ssh_key.private_key, commands: commands)

    action = ServerActions::DestroyProject.run_now!(server, project)

    assert action.reload.success?
    assert_not Project.exists?(project.id)
  end

  test "rejects a child server change after enqueue" do
    project = projects(:default)
    action = ServerActions::DestroyProject.create!(server: project.server, actionable: project)
    services(:postgres).update_columns(server_id: servers(:arm).id)
    ssh = mock("SSH session")
    ssh.expects(:execute!).never
    action.server.stubs(:ssh_session).yields(ssh)

    assert_raises(ActiveRecord::RecordInvalid) { RunServerActionJob.perform_now(action) }
    assert action.reload.error?
    assert Project.exists?(project.id)
  end

  test "rejects mismatched children at enqueue" do
    project = projects(:default)
    apps(:smol_roda).update_columns(server_id: servers(:arm).id)

    assert_no_difference -> { ServerAction.count } do
      assert_raises(ActiveRecord::RecordInvalid) do
        ServerActions::DestroyProject.run_later!(project.server, project)
      end
    end
  end

  test "records a failed job when the project server changes after enqueue" do
    project = projects(:default)
    action = ServerActions::DestroyProject.create!(server: project.server, actionable: project)
    project.update_columns(server_id: servers(:arm).id)
    ssh = mock("SSH session")
    ssh.expects(:execute!).never
    action.server.stubs(:ssh_session).yields(ssh)

    assert_raises(ActiveRecord::RecordInvalid) { RunServerActionJob.perform_now(action) }
    assert action.reload.error?
    assert Project.exists?(project.id)
  end

  test "rejects an app from a different account before executing commands" do
    project = projects(:default)
    apps(:smol_roda).update_columns(account_id: accounts(:other).id)
    action = ServerActions::DestroyProject.new(server: project.server, actionable: project)
    ssh = mock("SSH session")
    ssh.expects(:execute!).never
    action.ssh_session = ssh

    assert_raises(ActiveRecord::RecordInvalid) { action.send(:run) }
    assert Project.exists?(project.id)
    assert Service.exists?(services(:postgres).id)
  end

  test "rejects a mismatched service before deleting any apps" do
    project = projects(:default)
    services(:postgres).update_columns(server_id: servers(:arm).id)
    action = ServerActions::DestroyProject.new(server: project.server, actionable: project)
    ssh = mock("SSH session")
    ssh.expects(:execute!).never
    action.ssh_session = ssh

    assert_raises(ActiveRecord::RecordInvalid) { action.send(:run) }
    assert Project.exists?(project.id)
    assert App.exists?(apps(:smol_roda).id)
  end

  test "rejects destruction on a different server before executing commands" do
    project = projects(:default)
    action = ServerActions::DestroyProject.new(server: servers(:arm), actionable: project)
    ssh = mock("SSH session")
    ssh.expects(:execute!).never
    action.ssh_session = ssh

    assert_raises(ActiveRecord::RecordInvalid) { action.send(:run) }
    assert Project.exists?(project.id)
    assert App.exists?(apps(:smol_roda).id)
  end
end
