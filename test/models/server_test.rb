require "test_helper"

class ServerTest < ActiveSupport::TestCase
  setup do
    @server = servers(:amd)
  end

  describe "#ssh_session" do
    test "gives up after 4 connection timeouts" do
      Ssh::Session.any_instance.expects(:connect).times(4).raises(Net::SSH::ConnectionTimeout)

      assert_raises Net::SSH::ConnectionTimeout do
        @server.ssh_session {}
      end
    end

    test "retries connection timeouts until the connection succeeds" do
      Ssh::Session.any_instance.expects(:connect).times(3)
        .raises(Net::SSH::ConnectionTimeout).then
        .raises(Net::SSH::ConnectionTimeout).then
        .returns(:connected)

      assert_equal :connected, @server.ssh_session {}
    end
  end
end
