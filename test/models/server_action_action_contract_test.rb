require "test_helper"

class ServerActionActionContractTest < ActiveSupport::TestCase
  test "deployment log notification failure can retry the unbroadcast chunk" do
    run = ServerAction::Enqueue.build(action: ServerActions::DeployApp, target: deployments(:pending_deployment))
    operation = ServerAction::Registry.build(run)
    command = Ssh::Command.new("test-only-command")
    command.append_output(:stdout, "test-only-chunk")
    order = sequence("log notification recovery")
    operation.expects(:broadcast_log_chunk).with("test-only-chunk").in_sequence(order).raises(IOError, "broadcast unavailable")
    operation.expects(:broadcast_log_chunk).with("test-only-chunk").in_sequence(order)
    assert_raises(IOError) { operation.on_logs_persisted(commands: [command]) }
    operation.on_logs_persisted(commands: [command])
  end
  test "execute performs remote restart and success reconciliation activates target separately" do
    app = apps(:smol_roda)
    run = ServerAction::Enqueue.build(action: ServerActions::RestartApp, target: app)
    operation = ServerAction::Registry.build(run)
    ssh = mock("SSH session")
    ssh.expects(:execute!).with(instance_of(Dokku::Ps::RestartCommand))
    operation.validate!
    operation.execute!(ssh)
    assert app.reload.restarting?
    operation.succeeded!
    assert app.reload.active?
  end

  test "domain actions reject a cross tenant parent app before SSH" do
    domain = domains(:domain_test_secondary)
    domain.app.update_columns(account_id: accounts(:other).id)
    Net::SSH.expects(:start).never
    assert_raises(ArgumentError) { ServerAction::Enqueue.call(action: ServerActions::CreateDomain, target: domain) }
  end
end
