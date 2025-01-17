module ServerActionTestHelper
  def assert_server_action_scheduled(klass, server:, actionable:, payload: nil)
    server_action = ServerAction.find_by(type: klass.to_s, account: server.account, server:, actionable:)
    assert server_action
    return unless payload.present?

    payload.each do |key, value|
      assert_equal value, server_action.public_send(key)
    end
  end
end
