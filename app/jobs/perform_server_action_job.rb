class PerformServerActionJob < ApplicationJob
  limits_concurrency to: 1, key: ->(server_action) { server_action.concurrency_key }, duration: 30.minutes

  def perform(server_action)
    return unless server_action.queued?

    if server_action.preceding_action&.failure?
      return server_action.cancelled!
    end

    Current.org = server_action.org
    Current.server = server_action.server

    server_action.perform_action
  end
end
