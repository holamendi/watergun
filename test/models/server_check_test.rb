require "test_helper"

class ServerCheckTest < ActiveSupport::TestCase
  setup do
    @server = servers(:amd)
  end

  test "belongs to server" do
    check = server_checks(:recent)
    assert_equal @server, check.server
  end

  test "account defaults to server account" do
    check = ServerCheck.create!(
      server: @server,
      cpu_usage: 10.0,
      memory_usage: 20.0,
      timestamp: Time.current
    )
    assert_equal @server.account, check.account
  end

  test "trim_in_batches removes old checks" do
    recent_id = server_checks(:recent).id
    old_id = server_checks(:old).id

    assert_difference -> { ServerCheck.count }, -1 do
      ServerCheck.trim_in_batches(older_than: 1.day.ago)
    end

    assert ServerCheck.exists?(id: recent_id)
    assert_not ServerCheck.exists?(id: old_id)
  end
end
