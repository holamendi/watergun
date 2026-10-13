require "test_helper"
require_relative "../../app/models/ssh/session"

class ServerSshSessionTest < ActiveSupport::TestCase
  test "connection timeout stops after four attempts" do
    Net::SSH.expects(:start).times(4).raises(Net::SSH::ConnectionTimeout)

    assert_raises(Net::SSH::ConnectionTimeout) do
      servers(:amd).ssh_session { flunk "must not yield without a connection" }
    end
  end

  test "timeout from yielded operation never replays the mutation" do
    Net::SSH.expects(:start).at_least_once.yields(mock("transport"))
    mutations = 0

    assert_raises(Net::SSH::ConnectionTimeout) do
      servers(:amd).ssh_session do
        mutations += 1
        raise Net::SSH::ConnectionTimeout
      end
    end

    assert_equal 1, mutations
  end

  test "fourth connection attempt can succeed and yields once" do
    server = servers(:amd)
    transport = mock("transport")
    transport.expects(:loop).once
    attempts = sequence("connection attempts")
    arguments = [server.public_ip, SshKey::USER, {
      port: server.ssh_port, key_data: [server.ssh_key.private_key],
      keys_only: true, non_interactive: true
    }]
    Net::SSH.expects(:start).with(*arguments).times(3)
      .in_sequence(attempts).raises(Net::SSH::ConnectionTimeout)
    Net::SSH.expects(:start).with(*arguments).once
      .in_sequence(attempts).yields(transport)
    yielded = []

    result = server.ssh_session { |session| yielded << session }

    assert_instance_of Ssh::Session, result
    assert_equal [result], yielded
    assert_equal [], result.commands
    assert result.started_at
    assert result.finished_at
  end

  test "timeout while draining an established session never replays the mutation" do
    transport = mock("transport")
    transport.expects(:loop).at_least_once.raises(Net::SSH::ConnectionTimeout)
    Net::SSH.expects(:start).at_least_once.yields(transport)
    mutations = 0

    assert_raises(Net::SSH::ConnectionTimeout) do
      servers(:amd).ssh_session { mutations += 1 }
    end

    assert_equal 1, mutations
  end

  test "authentication failure is not retried" do
    Net::SSH.expects(:start).once.raises(Net::SSH::AuthenticationFailed)

    assert_raises(Net::SSH::AuthenticationFailed) do
      servers(:amd).ssh_session { flunk "must not yield without a connection" }
    end
  end
end
